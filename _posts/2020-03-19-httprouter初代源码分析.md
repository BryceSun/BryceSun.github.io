---
title: httprouter初代源码分析
date: 2020-03-19 16:00:00
categories: [golang]
tags: [httprouter]     # TAG 名称应始终为小写，但实测好像不需要
image:
  path: assets/img/blog_face/httprouter初代源码分析.png
  alt: 
---
## 阅前了解——uri,url,urn

    
                            hierarchical part
            ┌───────────────────┴─────────────────────┐
                        authority               path
            ┌───────────────┴───────────────┐┌───┴────┐
      abc://username:password@example.com:123/path/data?key=value&key2=value2#fragid1
      └┬┘   └───────┬───────┘ └────┬────┘ └┬┘           └─────────┬─────────┘ └──┬──┘
    scheme  user information     host     port                  query         fragment
    
      urn:example:mammal:monotreme:echidna
      └┬┘ └──────────────┬───────────────┘
    scheme              path
    
![image](https://upload.wikimedia.org/wikipedia/commons/thumb/d/d6/URI_syntax_diagram.svg/1920px-URI_syntax_diagram.svg.png)   
   
## httprouter.go
```
// Copyright 2013 Julien Schmidt. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.
//这是个基于树形结构的HTTP请求路由器
package httprouter

import (
	"errors"
	"net/http"
)

//跟http.HandlerFunc差不多的回调函数，用于注册到路由中以便处理响应、请求
//但还额外多了对请求参数的处理
type HandlerFunc func(http.ResponseWriter, *http.Request, map[string]string)

//没匹配到请求路径，就格式化后重定向，
func NotFound(w http.ResponseWriter, req *http.Request) {
	if req.Method != "CONNECT" {
		if p := CleanPath(req.URL.Path); p != req.URL.Path && p != req.Referer() {
			http.Redirect(w, req, p, http.StatusMovedPermanently)
			return
		}
	}

	http.NotFound(w, req)
}


//Router 实现了http包下的Handler接口，
//它可以通过可配置的路由将多个请求分发给不同的回调函数
type Router struct {

    //继承路径树节点类，后面有调用node的getValue()方法
	node

	//是否通过对请求路径末尾进行添加“/”或删除“/”以进行响应
	//例如配置的路由是“/foo”,但请求路径是"/foo/",此时可重定向至“/foo”,并且返回状态码301
	RedirectTrailingSlash bool


	//默认用于处理404请求的回调函数，默认为http包下的HandlerFunc
	NotFound NotFound


	//错误处理函数，对出现在路由回调函数中出现的错误进行处理。
	//第三个参数是？，这个函数有利于避免应用崩溃从而提高应用的高可用性
	PanicHandler func(http.ResponseWriter, *http.Request, interface{})
}


//确保http.Handler在当前包依赖中，是个开发小技巧吧
//删掉其实也没关系的
var _ http.Handler = New()

// The router can be configured to also match the requested HTTP method or the
// requested Host.
//用于返回一个实例化的Router对象的指针，其对象默认斜杠
//可配置这个对象以匹配Http请求方法或主机
func New() *Router {
	return &Router{
		RedirectTrailingSlash: true,
		NotFound:              http.NotFound,
	}
}


//归Router所有的方法，用于对给定的路径注册一个请求回调函数
func (r *Router) Add(path string, h HandlerFunc) error {

    //路径头部字符必须为斜杠，否则报错
	if path[0] != '/' {
		return errors.New("Path must begin with /")
	}
	return r.addRoute(path, h)
}

//让Router实现 http.Handler 接口的方法ServeHTTP
func (r *Router) ServeHTTP(w http.ResponseWriter, req *http.Request) {

    //错误处理函数不为空则定义延迟调用函数以恢复错误
	if r.PanicHandler != nil {
	    //defer 会在当前函数或者方法返回之前执行传入的函数
		defer func() {
	        //Recover 是一个内置函数用来重新获取对失控协程的控制。恢复仅在延迟函数内有效
	        //有错误则调用错误处理函数进行处理
			if rcv := recover(); rcv != nil {
				r.PanicHandler(w, req, rcv)
			}
		}()
	}
    //获取请求的路径
	path := req.URL.Path

    //获取路径对应的回调函数，请求参数以及斜杠重定向标识
	if handle, vars, tsr := r.getValue(path); handle != nil {
	    //调用回调函数处理相应、请求及其参数
		handle(w, req, vars)
	} else if tsr && r.RedirectTrailingSlash {
	    //没有获取到对应的回调函数但是允许斜杠重定向就进一步处理
		if path[len(path)-1] == '/' {
		    //路径末尾有斜杠就去斜杠并重定向
			http.Redirect(w, req, path[:len(path)-1], http.StatusMovedPermanently)
			return
		} else {
		    //路径末尾没有斜杠就加斜杠并重定向
			http.Redirect(w, req, path+"/", http.StatusMovedPermanently)
			return
		}
	} else { // 处理404请求
		r.NotFound(w, req)
	}
}

```
### 3.tree.go
```
// Copyright 2013 Julien Schmidt. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

package httprouter

import (
	"errors"
)

//用于获取两个整型中的最小值
func min(a, b int) int {
	if a <= b {
		return a
	}
	return b
}
//异常预定义
var (
    //路径重复注册异常
	ErrDuplicatePath     = errors.New("Duplicate Path")
	//特殊节点参数名缺乏异常
	ErrEmptyWildcardName = errors.New("Wildcards must be named with a non-empty name")
	//特殊节点通配冲突，通配节点只能在路径名后部
	ErrCatchAllConflict  = errors.New("CatchAlls are only allowed at the end of the path")
	//子节点冲突异常，特殊节点不可加入，因为被挂载的节点已存在子节点
	ErrChildConflict     = errors.New("Can't insert a wildcard route because this path has existing children")
	//通配符冲突异常
	ErrWildCardConflict  = errors.New("Conflict with wildcard route")
)

//树形节点结构
type node struct {
	// parent *node
	key        string       //对应路径节点名
	indices    []byte       //保存各子节点路径名头字符
	children   []*node      //子节点数组
	value      HandlerFunc  //回调函数
	wildChild  bool         //当前节点是否有特殊子节点（包括参数节点和通配节点）
	isParam    bool         //当前节点是否为参数节点
	isCatchAll bool         //当前节点是否为通配节点
}

//根据给定的路径节点名和对应的回调函数创建子节点并添加到路由树中
//此方法线程不安全
func (n *node) addRoute(key string, value HandlerFunc) error {

	//如果当前节点路径名不为空
	if len(n.key) != 0 {
	OUTER:
		for {

			//找出当前节点路径名与被添加路径节点名的最长公共前缀字符串
			//公共前缀字符串并不包含':'或'*'
			//因为节点路径名不能包含这些字符
			i := 0
			for j := min(len(key), len(n.key)); i < j && key[i] == n.key[i]; i++ {
			}
			//此时i是在共同前缀字符串之后的第一个字符的索引
			//对两者的路径名以i索引为起点进行分割
			
			//如果i等于(大于是不可能的)当前节点名长度，说明当前节点名都是两者的共同前缀
			if i < len(n.key) {
			
			    //当前节点名从i索引开始(除去共同前缀)有剩余，则以其i索引往后的字符串作为路径名创建子节点
			    //并将当前节点的剩余属性值赋予新建的子节点
				n.children = []*node{&node{
					key:       n.key[i:],
					indices:   n.indices,
					children:  n.children,
					value:     n.value,
					wildChild: n.wildChild,
				}}
				
				//将i索引处的字符作为当前节点的索引值，也就是共同前缀的下一个字符
				n.indices = []byte{n.key[i]}
				
				//其i索引往前的字符串作为当前节点的路径名
				n.key = key[:i]
				n.value = nil //无回调函数
				n.wildChild = false //非通配符子节点
			}

			// Make new Node a child of this node
			
            //判断被添加的路径名从i索引开始(除去共同前缀)是否有剩余
			if i < len(key) {
				//有剩余，则以其i索引往后的字符串作为路径名
				key = key[i:]
				
				//判断当前节点是否有特殊子节点
				if n.wildChild {
				    //如果是就将其特殊子节点设为当前节点
					n = n.children[0]

					// Check if the wildcard matches
					//判断当前节点路径名是否为被添加路径名的头部或全部
					if len(key) >= len(n.key) && n.key == key[:len(n.key)] {
						// check for longer wildcard, e.g. :name and :namex
						//如果是头部，而被添加路径名的头部之后却不是'/'，就报错
						if len(n.key) < len(key) && key[len(n.key)] != '/' {
							return ErrWildCardConflict
						}
						continue OUTER
					} else {
					    //特殊节点冲突
					    //类似于将“abc/go:who”路径添加到“abc/go:where”路径节点的情况
						return ErrWildCardConflict
					}
				}
				
				//获取被添加路径名i索引处的字符
				c := key[0]

				// TODO: remove / edit for variable delimiter
				//当前节点是参数节点，且被添加路径名i索引处是 '/',
				//并且参数节点下还有一个子节点，形如 :user / hello,:user / world
				//就跳出并继续迭代
				if n.isParam && c == '/' && len(n.children) == 1 {
					n = n.children[0]
					continue OUTER
				}

				//如果在当前节点的索引数组中找到被添加路径名的共同前缀的下一个字符，
				//就选择相应的子节点作为当前节点继续
				for i, index := range n.indices {
					if c == index {
						n = n.children[i]
						continue OUTER
					}
				}

                //判断i索引处的字符(被添加路径名的共同前缀的下一个字符)是否为':'或'*'
				if c != ':' && c != '*' {
				    //都不是，则将i索引处的字符添加到当前节点的索引数组中
					n.indices = append(n.indices, c)
					child := &node{}
					n.children = append(n.children, child)
					n = child
				}
				//将不重复部分的路径名和回调函数保存到新节点中
				return n.insertRoute(key, value)

			} else if i == len(key) { // Make node a (in-path) leaf
			    //处理‘/hello/’添加到‘/hello/*’的这种情况
				if n.wildChild && n.children[0].isCatchAll {
					panic("conflict with catchAll route")
				}
			    //被添加的路径名等于共同前缀，
				if n.value != nil {
				    //当前节点有回调函数说明当前节点名也等于共同前缀，
				    //因为如果不等于的话，那么n代表的是新节点，里面是没有回调函数的。
				    //说明路由重复添加了
					return ErrDuplicatePath
				}
				//将回调函数赋予当前新节点
				n.value = value
			}
			//无错误返回
			return nil
		}
	} else { // 如果当前节点路径名为空
		return n.insertRoute(key, value)
	}
}

//将路径节点名和对应的回调函数保存到当前节点
func (n *node) insertRoute(key string, value HandlerFunc) error {

    //定义偏移量，初始化值为0
	var offset int


	//找到最近的特殊符(此处仅指':'或'*'')前的字符串
	for i, j := 0, len(key); i < j; i++ {
	    //找到有特殊符就进行处理
		if b := key[i]; b == ':' || b == '*' {

			//检查此节点是否存在子节点，存在则不宜插入新的子节点
			if len(n.children) > 0 {
				return ErrChildConflict
			}

			k := i + 1
			/user:name
			//获取靠特殊符最近的'/'的索引，或路径名最后一个字符的索并加1
			for k < j && key[k] != '/' {
			    //通配符后面还有字符且跟在后面的不是'/'
				k++
			}
            //特殊符后面没有字符或跟在后面的是'/''
			if k-i == 1 {
			    //返回无通配符名字错误
				return ErrEmptyWildcardName
			}

            //如果是*通配符且,k不等于路径长度，说明k为/'的索引
            //说明路径名类似这个格式“*abcd/adbc”
			if b == '*' && len(key) != k {
			    //返回通配全部冲突错误
				return ErrCatchAllConflict
			}

			//新建特殊节点
			child := &node{}
			if b == ':' {
				child.isParam = true //参数节点
			} else {
				child.isCatchAll = true //通配节点
			}

            //如果特殊符不是路径名的第一个字符，
            //那么当前节点的路径名就设为特殊符前面的字符串
			if i > 0 {
				n.key = key[offset:i]
				offset = i
			}

            //将特殊节点挂载到当前节点
			n.children = []*node{child}
			//当前节点有特殊节点
			n.wildChild = true
			
			//将特殊节点设为当前节点
			n = child

			//如果k小于路径名长度，则此时k等于'/'的索引
			//k索引开始往后还有字符串，需进一步分割路径名
			if k < j {
			    //将'/'和通配符之间的字符作为通配符节点的路径名
				n.key = key[offset:k]
				offset = k

				child := &node{}
				n.children = []*node{child}
				//重设当前节点
				n = child
			}
		}
	}

	//将当前节点路径名与对应回调函数保存到节点中
	n.key = key[offset:]
	n.value = value
	
	//返回空错误，即正常运行
	return nil
}


//根据给定路径名获取回调函数、斜杠优化重定向标识以及保存在map中的被通配符匹配到的值，
//如果根据给定路径名没有获取到回调函数，但是经过斜杠优化后能找到，那么斜杠优化重定向标示会被设置为true,否则为false
func (n *node) getValue(key string) (value HandlerFunc, vars map[string]string, tsr bool) {

	// 迭代节点，如果是刚进入此方法，n此时是一整个路由树，迭代会从根节点开始。
OUTER:
    //如果当前节点路径名是给定路径名的头部或全部
	for len(key) >= len(n.key) && key[:len(n.key)] == n.key {
	
		key = key[len(n.key):]
	    //如果是全部，说明检索到给定路由
		if len(key) == 0 {

			//如果当前节点有这回调函数就返回
			if value = n.value; value != nil {
				return //隐式返回的是value
			}

			//查询当前节点是否有以'/''开头的子节点，有就处理并返回
			for i, index := range n.indices {
				if index == '/' {
					n = n.children[i]
					tsr = (n.key == "/" && n.value != nil)
					return
				}
			}
			return

		} else if n.wildChild == true {
			//设定特殊子节点为当前节点
			n = n.children[0]

			if n.isParam {
				// find param end (either '/'' or key end)
				//找到给定路径名最近的'/'索引，或结尾字符索引+1
				k := 0
				l := len(key)
				for k < l && key[k] != '/' {
					k++
				}

				// 从参数节点中获取路径名作为参数名，从给定路径名获取参数值
				if vars == nil {
					//vars = new(Vars)
					//vars.add(n.key[1:], key[:k])
					vars = map[string]string{
						n.key[1:]: key[:k],
					}
				} else {
				    //n.key[0]等于':'
					vars[n.key[1:]] = key[:k]
				}

				//k索引处为'/',则需进一步迭代
				if k < l {
					if len(n.children) > 0 {
						key = key[k:]
						n = n.children[0]
						continue
					} else { //判断'/'斜杠是否为结尾,则设置斜杠优化标识符为true
					    //这里不应该再判断下当前节点是否有回调函数？
					    //当前节点是末尾节点，肯定有回调函数
						tsr = (l == k+1)
						return
					}
				}
                //k索引处为末尾之后，则说明给定路径匹配到了
				if value = n.value; value != nil {
					return
				} else if len(n.children) == 1 {
					//无回调函数，则获取参数节点的子节点，
					//特殊节点的子节点有且只有一个，因为跟在参数节点后面的只能是'/'
					n = n.children[0]
					//说明可进行斜杠优化重定型，然后就能够检索到回调函数了
					tsr = n.key == "/" && n.value != nil
				}
				return

			} else { // catchAll
				// save value
				if vars == nil {
					vars = map[string]string{
						n.key[1:]: key,
					}
				} else {
					vars[n.key[1:]] = key
				}

				value = n.value
				return
			}

		} else {
		    //当前节点是给定路径名的头部，则查询索引数组做进一步处理
			c := key[0]

			for i, index := range n.indices {
				if c == index {
				    //给定路径名头部之后的字符在索引数组中，就迭代相应子节点
					n = n.children[i]
					continue OUTER
				}
			}

			//没有检索到子节点，则判断截取后的路径名是否为'/',是则设置斜杠优化标识为true
			tsr = key == "/" && n.value != nil
			return
		}
	}

	//给定路径是当前节点的头部，则判断是否可进行斜杠优化重定向。
	tsr = (n.value != nil && len(key)+1 == len(n.key) && n.key[len(key)] == '/') || (key == "/")
	return
}

```

### 4. path.go

```
// Copyright 2013 Julien Schmidt. All rights reserved.
// Based on the path package, Copyright 2009 The Go Authors.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

package httprouter

//清理给定的路径名，清除给定路径名中的‘.’，‘..’，返回规范的路径
func CleanPath(p string) string {
    //给定路径名为空就返回"/"
	if p == "" {
		return "/"
	}

	n := len(p)
	var buf []byte

	// r用来记录给定路径p下一个被读取的字符小标
    // w用来记录子节数组buf下一个被写入的元素小标
	//假定给定路径是以'/'开头，下一个被读写的下标默认为第二个数(下标为1)
	r := 1
	w := 1

    //路径名必须以'/'开头
	if p[0] != '/' {
	    //给定路径并不是以'/'开头，设置被读取的数是第一个
		r = 0
		//初始化多一子节的缓存数组，并写入第一个字符'/'
		buf = make([]byte, n+1)
		buf[0] = '/'
	}
	
    //给定路径是否至少3个字符且以斜杠结尾，类似‘/a/’,'aa/','///'
	trailing := n > 2 && p[n-1] == '/'

	// A bit more clunky without a 'lazybuf' like the path package, but the loop
	// gets completely inlined (bufApp). So in contrast to the path package this
	// loop has no expensive function calls (except 1x make)

    //迭代读取
	for r < n {
		switch {
		//读取到‘/’，跳过继续读下一个
		case p[r] == '/':
			// empty path element, trailing slash is added after the end
			r++
			
        //最后一个字符是'.',需要对优化后的路径加'/'结尾
		case p[r] == '.' && r+1 == n:
			trailing = true
			r++

        //遇到'./'组合，跳过'.'
		case p[r] == '.' && p[r+1] == '/': 
			// . element
			r++

        //遇到'..'结尾或'../'组合
		case p[r] == '.' && p[r+1] == '.' && (r+2 == n || p[r+2] == '/'):
			// .. element: remove to last /
			//跳过'..',并移动到最近的'/'
			r += 2
			
            //如果已经写入缓存至少两个字符了
			if w > 1 {
				// can backtrack
				//写下标回退一位，因为当前buf[w]还未写入缓存
				w--
                
                //缓存数组没有初始化，说明给定路径是以'/'开头
				if buf == nil {
					for w > 1 && p[w] != '/' {
						w--
					}
				} else {
					for w > 1 && buf[w] != '/' {
						w--
					}
				}
			}

		default:
		    //此时p[r]为非'/'和'.'字符
			//起码要在缓存区写第三个字符的时候需要添加'/'
			//换句话说就是，最起码先把下一个循环运行一遍，这边的w>1才成立
			if w > 1 {
				bufApp(&buf, p, w, '/')
				w++
			}

			// 将离目前r下标到最近的'/'之间的字符串写入缓存。
			for r < n && p[r] != '/' {
				bufApp(&buf, p, w, p[r])
				w++
				r++
			}
		}
	}

	//至少有两个字符写入缓存，可考虑重新添加结尾斜杠
	if trailing && w > 1 {
		bufApp(&buf, p, w, '/')
		w++
	}

	// 将空字符转换为"/"
	if w == 0 {
		return "/"
	}
    //并不是空串，buf也没有初始化，说明
	if buf == nil {
		return p[:w]
	}
	return string(buf[:w])
}

// internal helper to lazily create a buffer if necessary
//如果有必要，就需要辅助懒加载缓存数组
func bufApp(buf *[]byte, s string, w int, c byte) {
	if *buf == nil {
	    //只要r和w是相等的就可以进行懒加载。
	    //缓存数组还未初始化，
	    //且w下标处跟要准备写入缓存的字符相同就不操作
	    //等不相同了再进行操作
		if s[w] == c {
			return
		}
		//初始化缓存并将W小标之前的字符写入
		*buf = make([]byte, len(s))
		copy(*buf, s[:w])
	}
	写入w下标处的字符
	(*buf)[w] = c
}

```
## path.go算法总结
1. 判断给定路径的头部是否为'/',不是就将'/'作为第一个字符写入缓存数组
2. 以一个或多个'/'为界，读取'/'前的字符   
    2.1 读取到的是'.'就忽略   
    2.2 读取到是'..'就将缓存区的最后一个'/'字符之后的字符擦除   
    2.3 读取的是其它数据，就写入缓存，然后写入一个'/'   
3. 判断是否还有剩余，有就返回步骤2，没有就下个步骤
4. 如果给定路径结尾是'.'就將/添加到缓存
