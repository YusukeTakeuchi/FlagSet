# FlagSet
FlagSet is a Ruby library to make sets of finite flags.

## Installation
```
gem install flagset
```
## Usage
### define
You define a class with FlagSet.define:
```ruby
Auth = FlagSet.define{
  flag :allow_read_name
  flag :allow_read_email
  flag :allow_read_posts
}
```
Simpler ways are also available:
```ruby
Auth = FlagSet.define{
  flag :allow_read_name, :allow_read_email, :allow_read_posts
}
```
Or
```ruby
Auth = FlagSet.define(:allow_read_name, :allow_read_email, :allow_read_posts)
```

### create
```ruby
Auth.new
# => #<Auth: []> (empty set)
Auth.new(:allow_read_name, :allow_read_posts)
# => #<Auth: [:allow_read_name,:allow_read_posts]>
Auth[:allow_read_name, :allow_read_posts]
# => #<Auth: [:allow_read_name,:allow_read_posts]> (same as above)
```

### create with class methods
```ruby
Auth.allow_read_email
# => #<Auth: [:allow_read_email]> (same as Auth.new(:allow_read_email))

Auth.allow_read_name | Auth.allow_read_posts
# => #<Auth: [:allow_read_name,:allow_read_posts]>
```
You can use special name *all* and *none*
```ruby
Auth.all
# => #<Auth: [:allow_read_name,:allow_read_email,:allow_read_posts]>
Auth.none
# => #<Auth: []>
```

### aliases
*all* and *none* are aliases that denotes set of flags. You can also define aliases your own.
```ruby
Auth2 = FlagSet.define{
  aliased :read_all, [:read_name, :read_email, :read_posts]
  flag :read_name, :read_email, :read_posts

  flag :write_posts, :write_messages
  aliased :write_all, [:write_posts, :write_messages]
  # You can put aliased before or after the original names

  aliased :read_write_all, [:read_all, :write_all]
}

Auth2.read_all
# => #<Auth2: [:read_name,:read_email,:read_posts]>
Auth2.write_all
# => #<Auth2: [:write_posts,:write_messages]>
Auth2.read_write_all == Auth2.all
# => true
```

### Queries
You can check the state of the flags with *has_all_of?* and *has_any_of?* methods:
```ruby
Auth2.read_name.has_all_of?(:read_all)
# => false
Auth2.read_all.has_all_of?(:read_name, :read_email)
# => true
Auth2.write_all.has_all_of?(Auth2[:write_posts, :write_messages])
# => true
Auth2[:read_all].has_any_of?(:read_posts)
# => true
Auth2.read_all.has_any_of?(:write_all)
# => false
Auth2.all.has_any_of?(:none)
# => false
```

You can also use named query methods:
```ruby
Auth2.read_all.read_name?
# => true
Auth2.write_posts.write_all?
# => true
```
Note that the query method *#foo?* is equivalent to *has_any_of?(:foo)*, so
aliases can be confusing when used as query methods.

There are special query methods *all?*, *any?*, *none?*
```ruby
# #all? returns true if self is equal to class.all
Auth2.read_all.all? #=> false
(Auth2.read_all | Auth2.write_all).all? #=> true

# #any? returns true if self is not equal to class.none
Auth2.read_email.any? # => true
Auth2.new.any? # => false

# #none? returns true if self is equal to class.none
Auth2.read_posts.none? #=> false
Auth2.none.none? #=> true
```

### Set operations
Basic set operations are supported.
```ruby
Auth2.read_all & Auth2.read_name
# => #<Auth2: [:read_name]>

Auth2.read_name | Auth2.read_email
# => #<Auth2: [:read_name,:read_email]>

Auth2.read_all - :read_posts
# => #<Auth2: [:read_name,:read_email]>

Auth2[:read_name, :read_email] ^ [:read_email, :read_posts]
# => #<Auth2: [:read_name,:read_posts]>

~Auth2[:write_all]
# => #<Auth2: [:read_name,:read_email,:read_posts]>
```
The arguments of .new and set operations can be one of these:

* Symbol
* the same class as self
* Integer

or a single Array of above.


## License
MIT License
