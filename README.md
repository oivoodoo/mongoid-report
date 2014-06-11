# Mongoid Report

Library for easy building aggregation report using mongodb aggregation
framework.

### Example

```ruby
  class Model
    include Mongoid::Document

    field :field1, type: Integer, default: 0

    field :day,    type: Date
  end

  class Report1
    include Mongoid::Report

    aggregation_field :field1, for: Model
  end

  class Report2
    include Mongoid::Report

    attach_to Model do
      aggregation_field :field1
    end
  end

  class Report3
    include Mongoid::Report

    group_by :day, for: Model

    aggregation_field :field1, for: Model
  end

  class Report4
    include Mongoid::Report

    attach_to Model do
      group_by :day

      aggregation_field :field1
    end
  end
```

```ruby
  example = Report4.new
  result = example.aggregation_for(Model)

  result.is_a?(Array) => true
  result[0].is_a?(Hash) => true
```

## Installation

Add this line to your application's Gemfile:

    gem 'mongoid-report'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mongoid_report

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it ( http://github.com/<my-github-username>/mongoid_report/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
