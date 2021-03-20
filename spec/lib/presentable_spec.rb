RSpec.describe Presentable do
  class ExampleWithPresenter
    def initialize(obj) end

    def as_json(_options={})
      4
    end
  end

  class ExampleWith
    include Presentable
  end

  class ExampleWithoutAfterJson
    def as_json(_options={})
      3
    end
    include Presentable
  end

  class ExampleWithoutBeforeJson
    include Presentable
    def as_json(_options={})
      2
    end
  end

  class ExampleWithoutNoJson
    include Presentable
    def initialize(**attrs)
      attrs.each do |key, value|
        self.instance_variable_set("@#{key}", value)
      end
    end
  end

  class ExampleWithSuperPresenter
    def initialize(obj) end

    def as_json(_options={})
      1
    end
  end

  class ExampleWithSuper
    include Presentable
    def as_json(_options={})
      super
    end
  end

  it "should use defined as_json even if concern included" do
    expect(ExampleWithoutAfterJson.new.as_json).to eq(3)
    expect(ExampleWithoutBeforeJson.new.as_json).to eq(2)
  end

  it "should fall back to default as_json if presenter does not exist" do
    expect(ExampleWithoutNoJson.new(test: 'data').as_json).to eq({"test" => 'data'})
  end

  it "should use Presenter if it exists" do
    expect(ExampleWith.new.as_json).to eq(4)
  end

  it "should allow use of super to refer to Presentable as_json" do
    expect(ExampleWithSuper.new.as_json).to eq(1)
  end
end
