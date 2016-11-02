require 'tsort'
require 'equalizer'
require "flagset/version"

module FlagSet

  def self.define(*names, &block)
    if names.any? and block
      raise ArgumentError, 'symbols and block cannot be specified at once'
    end
    builder = Builder.new
    unless block
      block = lambda{| *_ |
        names.each{| name |
          flag name
        }
      }
    end
    builder.define(&block)
    Class.new(Base){
      define_singleton_method(:flagset_builder){
        builder
      }
      define_flags_class_methods
      define_flags_instance_methods
    }
  end

  class Builder
    attr_reader :elementary_flag_names
    attr_reader :all_flags_and_ints
    attr_reader :current_all_mask

    def initialize
      @elementary_flag_names = []
      @all_flags_and_ints = {}
      @current_all_mask = 0
    end

    def define(&block)
      @unresolved_aliases = {}.extend(AliasResolvingTSort)
      instance_eval(&block)
      @all_flags_and_ints[:all] = @current_all_mask
      @all_flags_and_ints[:none] = 0
      aliases = @unresolved_aliases.keys
      (@unresolved_aliases.tsort & aliases).each{| name |
        @all_flags_and_ints[name] =
          @unresolved_aliases[name].inject(0){| v,t_name |
            v | (@all_flags_and_ints[t_name] or raise NameError, "unknown flag name: #{t_name}")
          }
      }
    end

    # @param [Array<Symbol>] names
    # @option opts [Integer] :bits the bits to represent
    # @option opts [Integer] :bit alias for :bits
    def flag(*names, **opts)
      if bits = opts[:bit] || opts[:bits]
        if opts[:bit] and opts[:bits]
          raise ArgumentError, 'bit and bits cannot be specified at once'
        end
        unless names.size == 1
          raise ArgumentError, 'only one name can be specified with bit option'
        end
        if @current_all_mask & bits != 0
          raise ArgumentError, 'conflicting bits'
        end
        name = names.first
        error_if_already_in_use(name)
        @elementary_flag_names << name
        @all_flags_and_ints[name] = bits
        @current_all_mask |= bits
      else
        names.each{| fname |
          error_if_already_in_use(fname)
          bit = next_available_bit
          @elementary_flag_names << fname
          @all_flags_and_ints[fname] = bit
          @current_all_mask |= bit
        }
      end
    end

    def next_available_bit
      bit = 1
      until @current_all_mask & bit == 0
        bit <<= 1
      end
      bit
    end

    def aliased(name, targets)
      error_if_already_in_use(name)
      targets = [targets] unless targets.kind_of?(Enumerable)
      @unresolved_aliases[name] = targets
    end

    def error_if_already_in_use(name)
      if @all_flags_and_ints[name] or @unresolved_aliases[name]
        raise ArgumentError, "flag name #{name} is already in use"
      end
    end

    module AliasResolvingTSort
      include TSort

      def tsort_each_node(&block)
        each_key(&block)
      end

      def tsort_each_child(node, &block)
        (self[node] || []).each(&block)
      end
    end
  end

  # The class FlagSet.define creates derives from Base
  class Base
    include Equalizer.new(:to_i)

    def initialize(*args)
      @int_value = args_to_int_value(*args)
    end

    def to_i
      @int_value
    end

    def to_s
      '#<%s: [%s]>' % [
        self.class,
        to_names.map(&:inspect).join(',')
      ]
    end
    alias inspect to_s

    def to_names
      self.class.int_to_names(@int_value)
    end

    private
    def args_to_int_value(*args)
      if args.size == 1
        if args.first.kind_of?(Enumerable)
          objs = args.first
        else
          objs = [args.first]
        end
      else
        objs = args
      end
      enum_to_int_value(objs)
    end

    # @param [Array<Symbol,Base,Integer>] objs
    def enum_to_int_value(objs)
      objs.inject(0){| v,obj |
        v | (
          case obj
          when Symbol
            self.class.name_to_int(obj) or
              raise ArgumentError, "#{obj} is not defined in #{self.class}"
          when self.class
            obj.to_i
          when Integer
            unless consistent_int?(obj) and (~self.class.all_flags_mask & obj) == 0
              raise ArgumentError, "0x#{obj.to_s(16)} is a flag value inconsistent with #{self.class}"
            end
            obj
          else
            raise TypeError, "cannot convert to #{self.class}: #{obj}"
          end
        )
      }
    end

    # check if v is consistent with the set of flags
    # v is inconsistent in cases like:
    #   F = FlagSet.define{
    #     flag :some_flag, bits: 0xFF
    #   }
    #   F.new(1)
    # @param [Integer] v
    def consistent_int?(v)
      self.class.elementary_flag_names.all?{| name |
        mask = self.class.all_flags_and_ints[name]
        [0, mask].include?(mask & v)
      }
    end

    class << self
      def name_to_int(name)
        all_flags_and_ints[name] or raise NameError, "unknown flag name for #{self.class}: #{name}"
      end

      def int_to_names(int)
        elementary_flag_names.select{| name |
          (int & (all_flags_and_ints[name])) != 0
        }
      end

      def flagset_builder
        # abstract
      end

      # elementary flags are flags that are not aliases
      #
      # @return [Array<Symbol>]
      def elementary_flag_names
        flagset_builder.elementary_flag_names
      end

      # @return [Hash<Symbol,Integer>]
      def all_flags_and_ints
        flagset_builder.all_flags_and_ints
      end

      # @return [Integer]
      def all_flags_mask
        flagset_builder.current_all_mask
      end

      def [](*args)
        new(*args)
      end

      def define_flags_class_methods
        all_flags_and_ints.each{| k,v |
          define_singleton_method(k){
            new(v)
          }
        }
      end

      def define_flags_instance_methods
        all_flags_and_ints.each{| k,v |
          next if [:all, :none].include?(k)
          define_method("#{k}?"){
            has_any_of?(v)
          }
        }
      end
    end

    public
    ### set manipulation methods ###

    def &(*args)
      self.class.new(@int_value & args_to_int_value(*args))
    end
    alias intersect &

    def |(*args)
      self.class.new(@int_value | args_to_int_value(*args))
    end
    alias union |
    alias + |

    def -(*args)
      self.class.new(@int_value & ~args_to_int_value(*args))
    end
    alias difference -

    def ^(*args)
      self.class.new(@int_value ^ args_to_int_value(*args))
    end

    def ~@
      self.class.new(self.class.all_flags_mask & ~@int_value)
    end

    def subset?(*args)
      @int_value & ~args_to_int_value(*args) == 0
    end

    def proper_subset?(*args)
      v = args_to_int_value(*args)
      @int_value & ~v == 0 and @int_value != v
    end

    def superset?(*args)
      ~@int_value & args_to_int_value(*args) == 0
    end
    alias has_all_of? superset?

    def proper_superset?(*args)
      v = args_to_int_value(*args)
      ~@int_value & v == 0 and @int_value != v
    end

    def intersect?(*args)
      @int_value & args_to_int_value(*args) != 0
    end
    alias has_any_of? intersect?
    alias === intersect?

    def all?
      @int_value == self.class.all_flags_mask
    end

    def any?
      @int_value != 0
    end

    def none?
      @int_value == 0
    end

  end

end
