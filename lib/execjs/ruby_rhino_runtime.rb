module ExecJS
  class RubyRhinoRuntime
    class Context
      def initialize(source = "")
        source = ExecJS::encode(source) if source.respond_to?(:encode)

        @rhino_context = ::Rhino::Context.new
        fix_memory_limit! @rhino_context
        @rhino_context.eval(source)
      end

      def exec(source, options = {})
        source = ExecJS::encode(source) if source.respond_to?(:encode)

        if /\S/ =~ source
          eval "(function(){#{source}})()", options
        end
      end

      def eval(source, options = {})
        source = ExecJS::encode(source) if source.respond_to?(:encode)

        if /\S/ =~ source
          unbox @rhino_context.eval("(#{source})")
        end
      rescue ::Rhino::JSError => e
        message, trace = process_error(e)
        if syntax_error?(e)
          raise RuntimeError.new(message, trace)
        else
          raise ProgramError.new(message, trace)
        end
      end

      def call(properties, *args)
        unbox @rhino_context.eval(properties).call(*args)
      rescue ::Rhino::JSError => e
        message, trace = process_error(e)
        if syntax_error?(e)
          raise RuntimeError.new(message, trace)
        else
          raise ProgramError.new(message, trace)
        end
      end

      def unbox(value)
        case value = ::Rhino::to_ruby(value)
        when Java::OrgMozillaJavascript::NativeFunction
          nil
        when Java::OrgMozillaJavascript::NativeObject
          value.inject({}) do |vs, (k, v)|
            case v
            when Java::OrgMozillaJavascript::NativeFunction, ::Rhino::JS::Function
              nil
            else
              vs[k] = unbox(v)
            end
            vs
          end
        when Array
          value.map { |v| unbox(v) }
        else
          value
        end
      end

      private
        # Disables bytecode compiling which limits you to 64K scripts
        def fix_memory_limit!(context)
          if context.respond_to?(:optimization_level=)
            context.optimization_level = -1
          else
            context.instance_eval { @native.setOptimizationLevel(-1) }
          end
        end

        def syntax_error?(error)
          error.message =~ /^syntax error/
        end

        def process_error(error)
          message = error.message
          trace = error.javascript_backtrace.lines.to_a
          trace.map do |i|
            line, code = /at .*:(\d+) (.*)/.match(i).to_a[1,2]
            column = 0
            "at #{code} (<eval>:#{line}:#{column})"
          end
          [message, trace]
        end
    end

    def name
      "therubyrhino (Rhino)"
    end

    def exec(source)
      context = Context.new
      context.exec(source)
    end

    def eval(source)
      context = Context.new
      context.eval(source)
    end

    def compile(source)
      Context.new(source)
    end

    def available?
      require "rhino"
      true
    rescue LoadError
      false
    end
  end
end
