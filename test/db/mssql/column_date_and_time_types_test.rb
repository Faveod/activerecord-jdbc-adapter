require 'test_helper'
require 'db/mssql'

class MSSQLColumnDateAndTimeTypesTest < Test::Unit::TestCase
  class CreateDateAndTimeTypes < ActiveRecord::Migration
    def self.up
      create_table 'date_and_time_types', force: true do |t|
        t.column :my_date, :date
        t.column :my_date_one, :date, null: false, default: '23/06/1912'

        t.column :my_datetime, :datetime
        t.column :my_datetime_one, :datetime,  null: false, default: '2019-02-28 05:59:06.789'

        t.column :my_smalldatetime, :smalldatetime
        t.column :my_smalldatetime_one, :smalldatetime,  null: false, default: '2019-02-28 05:59:06'

        t.column :my_time, :time
        t.column :my_time_one, :time, precision: 3,  null: false, default: '15:59:06.456789'
      end
    end

    def self.down
      drop_table 'date_and_time_types'
    end
  end

  class DateAndTimeTypes < ActiveRecord::Base
    self.table_name = 'date_and_time_types'
  end

  def self.startup
    CreateDateAndTimeTypes.up
  end

  def self.shutdown
    CreateDateAndTimeTypes.down
    ActiveRecord::Base.clear_active_connections!
  end

  Type = ActiveRecord::ConnectionAdapters::MSSQL::Type

  def test_date_with_defaults
    column = DateAndTimeTypes.columns_hash['my_date']

    assert_equal :date,    column.type
    assert_equal true,     column.null
    assert_equal 'date',   column.sql_type
    assert_equal nil,      column.default

    type = DateAndTimeTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Date, type
  end

  def test_date_custom
    column = DateAndTimeTypes.columns_hash['my_date_one']

    assert_equal :date,        column.type
    assert_equal false,        column.null
    assert_equal 'date',       column.sql_type
    assert_equal '1912-06-23', column.default

    type = DateAndTimeTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Date, type
  end

  def test_datetime_with_defaults
    column = DateAndTimeTypes.columns_hash['my_datetime']

    assert_equal :datetime,  column.type
    assert_equal true,       column.null
    assert_equal 'datetime', column.sql_type
    assert_equal nil,        column.default

    type = DateAndTimeTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::DateTime, type
  end

  def test_datetime_custom
    column = DateAndTimeTypes.columns_hash['my_datetime_one']

    assert_equal :datetime,                    column.type
    assert_equal false,                        column.null
    assert_equal 'datetime',                   column.sql_type
    assert_equal '2019-02-28 05:59:06.789', column.default

    type = DateAndTimeTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::DateTime, type
  end

  def test_smalldatetime_with_defaults
    column = DateAndTimeTypes.columns_hash['my_smalldatetime']

    assert_equal :datetime,       column.type
    assert_equal true,            column.null
    assert_equal 'smalldatetime', column.sql_type
    assert_equal nil,             column.default

    type = DateAndTimeTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::SmallDateTime, type
  end

  def test_smalldatetime_custom
    column = DateAndTimeTypes.columns_hash['my_smalldatetime_one']

    assert_equal :datetime,             column.type
    assert_equal false,                 column.null
    assert_equal 'smalldatetime',       column.sql_type
    assert_equal '2019-02-28 05:59:06', column.default

    type = DateAndTimeTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::SmallDateTime, type
  end

  def test_time_with_defaults
    column = DateAndTimeTypes.columns_hash['my_time']

    assert_equal :time,     column.type
    assert_equal true,      column.null
    assert_equal 'time(7)', column.sql_type
    assert_equal nil,       column.precision
    assert_equal nil,       column.default

    type = DateAndTimeTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Time, type
  end

  def test_time_custom
    column = DateAndTimeTypes.columns_hash['my_time_one']

    assert_equal :time,             column.type
    assert_equal false,             column.null
    assert_equal 'time(3)',         column.sql_type
    assert_equal 3,                 column.precision
    assert_equal '15:59:06.456789', column.default

    type = DateAndTimeTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Time, type
  end

  def test_lookup_date_aliases
    assert_cast_type :date, 'DATE'
  end

  def test_lookup_datetime_aliases
    assert_cast_type :datetime, 'DATETIME'
  end

  def test_lookup_smalldatetime_aliases
    assert_cast_type :datetime, 'SMALLDATETIME'
  end

  def test_lookup_time_aliases
    assert_cast_type :time, 'time'
    assert_cast_type :time, 'TIME'
  end

  def test_smalldatetime_rounding_usec_to_zero_on_assigment
    # dt = DateTime.parse('2018-12-31T23:59:21.34343766')
    tt = Time.parse('2018-12-31T23:59:21.34343766')
    record = DateAndTimeTypes.new(my_smalldatetime: tt)
    # NOTE: rounding minutes and seconds is handled by MSSQL

    assert_equal 0,  record.my_smalldatetime.usec
  end

  # NOTE: The key here is to get usec in a format like ABC000 to get minimal
  # rounding issues. MSSQL has its own rounding strategy
  # (Rounded to increments of .000, .003, or .007 seconds)

  # rounding tries to converge to AB000
  def test_datetime_rounding_usec_on_assigment_case_one
    # dt = DateTime.parse('2018-12-31T23:59:21.343437')
    tt = Time.parse('2018-12-31T23:59:21.341167')
    record = DateAndTimeTypes.new(my_datetime: tt)

    assert_equal 23,     record.my_datetime.hour
    assert_equal 59,     record.my_datetime.min
    assert_equal 21,     record.my_datetime.sec
    assert_equal 340000, record.my_datetime.usec
  end

  # rounding tries to converge to AB300
  def test_datetime_rounding_usec_on_assigment_case_two
    # dt = DateTime.parse('2018-12-31T23:59:21.343537')
    tt = Time.parse('2018-12-31T23:59:21.342167')
    record = DateAndTimeTypes.new(my_datetime: tt)

    assert_equal 23,     record.my_datetime.hour
    assert_equal 59,     record.my_datetime.min
    assert_equal 21,     record.my_datetime.sec
    assert_equal 343000,  record.my_datetime.usec
  end

  # rounding tries to converge to AB600 or maybe AB700
  def test_datetime_rounding_usec_on_assigment_case_three
    # dt = DateTime.parse('2018-12-31T23:59:21.343537')
    tt = Time.parse('2018-12-31T23:59:21.345167')
    record = DateAndTimeTypes.new(my_datetime: tt)

    assert_equal 23,     record.my_datetime.hour
    assert_equal 59,     record.my_datetime.min
    assert_equal 21,     record.my_datetime.sec
    assert_equal 346000, record.my_datetime.usec
  end

  # rounding tries to converge to A(B+1)000
  def test_datetime_rounding_usec_on_assigment_case_four
    # dt = DateTime.parse('2018-12-31T23:59:21.344637').to_time
    tt = Time.parse('2018-12-31T23:59:21.348167')
    record = DateAndTimeTypes.new(my_datetime: tt)

    assert_equal 23,     record.my_datetime.hour
    assert_equal 59,     record.my_datetime.min
    assert_equal 21,     record.my_datetime.sec
    assert_equal 350000, record.my_datetime.usec
  end

  private

  def assert_cast_type(type, sql_type)
    cast_type = DateAndTimeTypes.connection.lookup_cast_type(sql_type)
    assert_equal type, cast_type.type
  end
end
