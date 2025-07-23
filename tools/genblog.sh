#!/usr/bin/env bash
#
# Generate a blog text template
# Usage: ./genblog.sh tittle category flag
# author:Feelord
# url:https://brycesun.github.io/
# shell chmod +x genblog.sh
# shell chmod 777 genblog.sh
# shell ./genblog.sh "标题" "分类" "标签"
# shell chmod [augo+rx] genblog.sh

echo "Generating a blog text template..."

title="$1"
category="$2"
flag="$3"

if [ -z "$title" ]; then
  echo "Error: Please provide a title for your blog."
  exit 1
fi

if [ -z "$category" ]; then
  category="未知分类"
fi

if [ -z "$flag" ]; then
  flag="未知标签"
fi

echo "Title: $title"
echo "Category: $category"
echo "Flag: $flag"

echo "Creating a new blog post..."

post_date=$(date +%Y-%m-%d)
post_name="$post_date-$title"
post_path="_posts/$post_name.md"

if [ -e "$post_path" ]; then
  echo "Error: Post already exists."
  exit 1
fi

{
  echo "---"
  echo "layout: post"
  echo "title: $title"
  echo "category: [$category]"
  echo "tags: [$flag]"
  echo "image:"
  echo " path: assets/img/blog_face/默认封面.png"
  echo " alt:"
  echo "---"
} >>"$post_path"

echo "Done!"
echo "You can now edit the file: $post_path"
