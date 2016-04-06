# DCD

DCD is a Ruby library for processing CHARMM and X-PLOR style binary trajectory files, aka DCD files. Based on the [`matdcd`](http://www.ks.uiuc.edu/Development/MDTools/matdcd/) and [VMD DCD plugin](http://www.ks.uiuc.edu/Research/vmd/plugins/doxygen/dcdplugin_8c-source.html), DCD parses and allows access to various metadata and atom information for use in scripts and automated environments where the numeric positions of the atoms is useful. 

## Installation

Add this line to your application's Gemfile:

    gem 'dcd'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install dcd


## Usage

DCD requires an io pointer to a binary DCD file upon initialization, and can be used in two ways: instant loading and lazy loading. The difference between instant and lazy loading is passing in an optional second argument upon initialization.

```ruby
> require('dcd')
=> true
> dcd_pointer = File.read('1407.dcd')
=> #<File:./1407.dcd>
> lazy_load = false
=> false
> my_dcd = DCD.new(dcd_pointer, lazy_load)
=> ... 
```

Once loaded, you have access to the metadata, including the `nstep`, `nset`, and `step`, the title, and the frames with atom coordinates in `x`, `y`, `z`, and `w` if using a 4th dimensional DCD.

## TODO

1. Currently test coverage on this library is limited, especially around fixed atoms and CHARMM 4th dimensional parameters. If you DCDs, especially those with the aforementioned features, please make a pull request or an issue with the necessary files attached.
2. Examples.

## License

MIT. See LICENSE for more information.