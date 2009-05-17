require File.dirname(__FILE__) + '/test_helper'

class SerializedAttributeWithSerializedDataTest < ActiveSupport::TestCase
  @@current_time = Time.now.utc.midnight
  @@raw_hash     = {:title => 'abc', :age => 5, :average => 5.1, :birthday => @@current_time.xmlschema, :active => true}
  @@encoded_hash = SerializedAttributes::Schema.encode(@@raw_hash)

  def setup
    @record  = SerializedRecord.new
    @changed = SerializedRecord.new
    @record.data   = @@encoded_hash
    @changed.data  = @@encoded_hash
    @changed.title = 'def'
    @changed.age   = 6
  end

  test "ignores data with extra keys" do
    @record.data = SerializedAttributes::Schema.encode(@@raw_hash.merge(:foo => :bar))
    assert_not_nil @record.title     # no undefined foo= error
    assert_equal false, @record.save # extra before_save cancels the operation
    assert_equal @@raw_hash.merge(:active => 1).stringify_keys, SerializedAttributes::Schema.decode(@record.data)
  end

  test "reads strings" do
    assert_equal @@raw_hash[:title], @record.title
  end
  
  test "clears strings with nil" do
    assert @record.raw_data.key?('title')
    @record.title = nil
    assert !@record.raw_data.key?('title')
  end
  
  test "reads integers" do
    assert_equal @@raw_hash[:age], @record.age
  end
  
  test "parses integers from strings" do
    @record.age = '5.5'
    assert_equal 5, @record.age
  end
  
  test "clears integers with nil" do
    assert @record.raw_data.key?('age')
    @record.age = nil
    assert !@record.raw_data.key?('age')
  end
  
  test "clears integers with blank" do
    assert @record.raw_data.key?('age')
    @record.age = ''
    assert !@record.raw_data.key?('age')
  end
  
  test "reads floats" do
    assert_equal @@raw_hash[:average], @record.average
  end
  
  test "parses floats from strings" do
    @record.average = '5.5'
    assert_equal 5.5, @record.average
  end
  
  test "clears floats with nil" do
    assert @record.raw_data.key?('average')
    @record.average = nil
    assert !@record.raw_data.key?('average')
  end
  
  test "clears floats with blank" do
    assert @record.raw_data.key?('average')
    @record.average = ''
    assert !@record.raw_data.key?('average')
  end
  
  test "reads times" do
    assert_equal @@current_time, @record.birthday
  end
  
  test "parses times from strings" do
    t = 5.years.ago.utc.midnight
    @record.birthday = t.xmlschema
    assert_equal t, @record.birthday
  end
  
  test "clears times with nil" do
    assert @record.raw_data.key?('birthday')
    @record.birthday = nil
    assert !@record.raw_data.key?('birthday')
  end
  
  test "clears times with blank" do
    assert @record.raw_data.key?('birthday')
    @record.birthday = ''
    assert !@record.raw_data.key?('birthday')
  end
  
  test "reads booleans" do
    assert_equal true, @record.active
  end
  
  test "parses booleans from strings" do
    @record.active = '1'
    assert_equal true, @record.active
    @record.active = '0'
    assert_equal false, @record.active
  end
  
  test "parses booleans from integers" do
    @record.active = 1
    assert_equal true, @record.active
    @record.active = 0
    assert_equal false, @record.active
  end
  
  test "converts booleans to false with nil" do
    assert @record.raw_data.key?('active')
    @record.active = nil
    assert !@record.raw_data.key?('active')
  end
  
   test "attempts to re-encode data when saving" do
     assert_not_nil @record.title
     @record.data = nil
     assert_equal false, @record.save # extra before_save cancels the operation
     assert_equal @@raw_hash.merge(:active => 1).stringify_keys, SerializedAttributes::Schema.decode(@record.data)
   end
  
  test "knows untouched record is not changed" do
    assert !@record.raw_data_changed?
    assert_equal [], @record.raw_data_changed
  end
  
  test "knows updated record is changed" do
    assert @changed.raw_data_changed?
    assert_equal %w(age title), @changed.raw_data_changed.sort
  end
  
  test "tracks if field has changed" do
    assert !@record.title_changed?
    assert  @changed.title_changed?
  end
  
  test "tracks field changes" do
    assert_nil @record.title_change
    assert_equal %w(abc def), @changed.title_change
  end
end

class SerializedAttributeTest < ActiveSupport::TestCase
  def setup
    @record = SerializedRecord.new
  end

  test "encodes and decodes data successfully" do
    hash = {:a => 1, :b => 2}
    encoded = SerializedAttributes::Schema.encode(hash)
    assert_equal SerializedAttributes::Schema.decode(encoded), hash.stringify_keys
  end

  test "defines #raw_data method on the model" do
    assert @record.respond_to?(:raw_data)
    assert_equal @record.raw_data, {}
  end

  attributes = {:string => [:title, :body], :integer => [:age], :float => [:average], :time => [:birthday], :boolean => [:active]}
  attributes.values.flatten.each do |attr|
    test "defines ##{attr} method on the model" do
      assert @record.respond_to?(attr)
      assert_nil @record.send(attr)
    end

    next if attr == :active
    test "defines ##{attr}_before_type_cast method on the model" do
      assert @record.respond_to?("#{attr}_before_type_cast")
      assert_equal "", @record.send("#{attr}_before_type_cast")
    end
  end

  test "defines #active_before_type_cast method on the model" do
    assert @record.respond_to?(:active_before_type_cast)
    assert_equal "0", @record.active_before_type_cast
  end

  attributes[:string].each do |attr|
    test "defines ##{attr}= method for string fields" do
      assert @record.respond_to?("#{attr}=")
      assert_equal 'abc', @record.send("#{attr}=", "abc")
      assert_equal 'abc', @record.raw_data[attr.to_s]
    end
  end

  attributes[:integer].each do |attr|
    test "defines ##{attr}= method for integer fields" do
      assert @record.respond_to?("#{attr}=")
      assert_equal 0, @record.send("#{attr}=", "abc")
      assert_equal 1, @record.send("#{attr}=", "1.2")
      assert_equal 1, @record.raw_data[attr.to_s]
    end
  end

  attributes[:float].each do |attr|
    test "defines ##{attr}= method for float fields" do
      assert @record.respond_to?("#{attr}=")
      assert_equal 0.0, @record.send("#{attr}=", "abc")
      assert_equal 1.2, @record.send("#{attr}=", "1.2")
      assert_equal 1.2, @record.raw_data[attr.to_s]
    end
  end

  attributes[:time].each do |attr|
    test "defines ##{attr}= method for time fields" do
      assert @record.respond_to?("#{attr}=")
      t = Time.now.utc.midnight
      assert_equal t, @record.send("#{attr}=", t.xmlschema)
      assert_equal t, @record.raw_data[attr.to_s]
    end
  end
end