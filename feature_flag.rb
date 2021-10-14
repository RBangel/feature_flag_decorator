module FeatureFlag
  def method_added(method)
    @method_store ||= MethodStore.new(self)
    @method_store.store(method)
  end

  def feature_flag flag
    @__check_feature_flags__ = {feature_flag: flag}
  end
end

class MethodStore
  def initialize(klass)
    @klass = klass
  end

  def run(instance, method, flag, args = nil) 
    setting = FeatureFlagSettings.check_flag(flag)
    unbound_method = stored_methods[method][flag][setting].bind(instance)
    unbound_method.call
  end

  def store(method)
    return if instruction == :skip
    return if !instruction && !method_flagged?(method)

    if instruction
      set = :on
      flag = instruction[:feature_flag]
    else
      set = :off
      flag = method_flag(method)
    end

    store_method(method, flag, set)
    define_wrapper(method, flag)

    klass.instance_variable_set self.class.instruction_variable, nil
  end

  def self.instruction_variable
    :@__check_feature_flags__
  end

  private

  attr_reader :klass

  def define_wrapper(method, flag)
    skip_flag_check do
      wrapped_method_name = :"#{method}_wrapped_with_feature_flags"
      unless klass.method_defined? wrapped_method_name
        klass.define_method(wrapped_method_name) do
          method_store = self.class.instance_variable_get :@method_store
          method_store.run(self, method, flag)
        end
      end
      klass.alias_method method, wrapped_method_name
    end
  end

  def skip_flag_check
    orig_value = klass.instance_variable_get :@__check_feature_flags__
    klass.instance_variable_set :@__check_feature_flags__, :skip
    yield
    klass.instance_variable_set :@__check_feature_flags__, orig_value
  end

  def method_flag(method)
    stored_methods[method].keys.first
  end

  def method_flagged?(method)
    stored_methods.keys.include? method
  end

  def store_method(method, flag, flag_value)
    stored_methods[method] ||= {}
    stored_methods[method][flag] ||= {}
    stored_methods[method][flag][flag_value] = klass.instance_method(method)
  end

  def stored_methods
    @stored_methods ||= {}
  end

  def instruction
    klass.instance_variable_get self.class.instruction_variable
  end
end

FLAG_SETTINGS = {}
class FeatureFlagSettings
  def self.enable!(flag)
    FLAG_SETTINGS[flag] = :on
  end

  def self.check_flag(flag)
    FLAG_SETTINGS[flag] || :off
  end
end
