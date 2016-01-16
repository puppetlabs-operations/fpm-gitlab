# fpm-gitlab

Building a more standard Debian package for GitLab CE, without the Omnibus installer.

# Usage

~~~
gem install rake fpm

# Build a package for gitlab-workhorse 0.5.4
rake deb_wh wh_tag=0.5.4 iteration=1

# Build a package for gitlab-ce 8.3.3
rake deb_gl gl_tag=v8.3.3 iteration=1
~~~
