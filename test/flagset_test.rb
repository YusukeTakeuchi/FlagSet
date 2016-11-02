require 'test_helper'

class FlagsetTest < Minitest::Test
  FS = FlagSet.define(:A, :B, :C, :D, :E)

  def test_that_it_has_a_version_number
    refute_nil ::Flagset::VERSION
  end

  def test_define
    klass = FlagSet.define{
      flag :read
      flag :write
      flag :update
    }
    assert_equal(0, klass.none.to_i)
    assert_equal(7, klass.all.to_i)

    assert_equal(1, klass.read.to_i)
    assert_equal(4, klass.update.to_i)

    assert_equal(2, klass[:write].to_i)

    assert_equal(0, klass.new.to_i)
    assert_equal(2, klass.new(:write).to_i)
  end

  def test_new
    klass = FlagSet.define{
      flag :A,:B,:C
    }
    assert_equal(%i(A B C), klass.new(7).to_names)
    assert_equal(%i(A B), klass.new(klass.new(3)).to_names)
    assert_raises(TypeError){
      klass.new(FS.new(:A))
    }
  end

  def test_define_short
    klass = FlagSet.define(:read, :write, :update)
    assert_equal(7, klass.all.to_i)
  end
  
  def test_aliased
    klass = FlagSet.define{
      flag :left, :right
      aliased :both, [:left,:right]
    }
    assert_equal(3, klass.both.to_i)

    klass = FlagSet.define{
      aliased :A, :B
      aliased :B, :C
      flag :C
    }
    assert_equal(1, klass.A.to_i)
    assert_equal(1, klass.B.to_i)
    assert_equal(1, klass.C.to_i)

    klass = FlagSet.define{
      flag :X
      aliased :everything, :all
      aliased :nothing, :none
    }
    assert_equal([:X], klass.everything.to_names)
    assert_equal([], klass.nothing.to_names)

    assert_raises(NameError){
      klass = FlagSet.define{
        aliased :X, :xxx
      }
    }
  end

  def test_bit
    klass = FlagSet.define{
      flag :allow_nil
      flag :do_type_check, bit: 0x80
    }
    assert_equal(0x81, klass.all.to_i)

    klass = FlagSet.define{
      flag :more_than_one_bits_allowed, bit: 0x41
      flag :extra
    }
    assert_equal(0x41, klass.more_than_one_bits_allowed.to_i)
    assert_equal(2, klass.extra.to_i)

    klass = FlagSet.define{
      flag :a, bit: 6
      flag :b
      flag :c
    }
    assert_equal(6, klass.a.to_i)
    assert_equal(1, klass.b.to_i)
    assert_equal(8, klass.c.to_i)

    assert_raises(ArgumentError){
      FlagSet.define{
        flag :x, bits: 2, bit: 2
      }
    }
    assert_raises(ArgumentError){
      FlagSet.define{
        flag :x
        flag :y, bit: 1
      }
    }
  end

  def test_consistent_int?
    klass = FlagSet.define{
      flag :a, bits: 7
      flag :b
    }
    assert_raises(ArgumentError){
      klass.new(3)
    }
    assert_raises(ArgumentError){
      klass.new(1)
    }
    assert_raises(ArgumentError){
      klass.new(0x10)
    }
  end

  def test_to_names
    klass = FlagSet.define{
      flag :x, :y, :z
    }
    assert_equal(%i(x z), klass.new(:z, :x).to_names)

    klass = FlagSet.define{
      flag :A, bits: 0xF0
      flag :B, bits: 0xC
      flag :C, bits: 3
    }
    assert_equal(%i(A C), klass.new(0xF3).to_names)
    assert_equal(%i(A B C), klass.new(0xFF).to_names)
  end

  def test_args_to_int_value
    obj = FlagSet.define(:A, :B, :C).new
    assert_equal(4, obj.__send__(:args_to_int_value, :C).to_i)
    assert_equal(4, obj.__send__(:args_to_int_value, [:C]).to_i)
    assert_equal(5, obj.__send__(:args_to_int_value, :A, :C).to_i)
  end

  def test_intersect
    assert_equal(FS[:B], FS.new(:A,:B) & :B)
    assert_equal(FS[:none], FS[:A,:B] & [:C])
  end

  def test_union
    assert_equal(FS[:A,:B], FS[:A] | :B)
  end

  def test_difference
    assert_equal(FS[:A,:B], FS[:A,:B,:C] - :C)
  end

  def test_xor
    assert_equal(FS[:A,:D], FS[:A,:B] ^ FS[:B,:D])
  end

  def test_complement
    assert_equal(FS[:D,:E], ~FS[%i(A B C)])
  end

  def test_subset?
    assert(FS[:A,:B].subset?(FS[:A,:B,:C]))
    assert(FS[:A,:B].subset?(FS[:A,:B]))
  end

  def test_proper_subset?
    assert(FS[:A,:B].proper_subset?(FS[:A,:B,:C]))
    refute(FS[:A,:B].proper_subset?(FS[:A,:B]))
  end

  def test_superset?
    assert(FS[:A,:B,:C].superset?(FS[:A,:B]))
    assert(FS[:A,:B].superset?(FS[:A,:B]))
    refute(FS[:A,:B].has_all_of?(:A,:B,:E))
  end

  def test_proper_superset?
    assert(FS[:A,:B,:C].proper_superset?(FS[:A,:B]))
    refute(FS[:A,:B].proper_superset?(FS[:A,:B]))
  end

  def test_intersect?
    assert(FS[:A,:B,:C].intersect?(FS[:A,:D]))
    refute(FS[:A,:B,:C].intersect?(:D,:E))
    assert(FS[:A,:B].has_any_of?(:A))
  end

  def test_eq3
    case :A
    when FS[:A]
      assert(true)
    when FS[:B]
      flunk
    else
      flunk
    end
  end

  def test_all?
    assert(FS[:A,:B,:C,:D,:E].all?)
    refute(FS[:A,:B,:C,:D].all?)
  end

  def test_any?
    assert(FS[:A].any?)
    refute(FS[].any?)
  end

  def test_none?
    assert(FS.new.none?)
    refute(FS[2].none?)
  end


  def test_query_methods
    so = FlagSet.define{
      aliased :lgbt, [:lesbian, :gay, :bisexual, :transgender]
      aliased :straight, [:female_straight, :male_straight]

      flag :lesbian, :gay, :bisexual, :transgender
      flag :female_straight, bits: 0x10100
      flag :male_straight, bits: 0x20200
    }
    assert(so.new(:gay).lgbt?)
    refute(so.new(:male_straight).lgbt?)
    refute(so.new(:lesbian, :transgender).straight?)
    assert(so.new(0x10100).female_straight?)
    refute(so.new(0x10100).male_straight?)
  end
end
