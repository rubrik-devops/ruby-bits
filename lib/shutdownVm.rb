require 'rbvmomi'

vim = RbVmomi::VIM.connect(host: 'foo', user: 'bar', password: 'baz')
