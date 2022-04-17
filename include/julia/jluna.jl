
module jluna

    """
    `safe_call(::Function, args...) ::Tuple{Any, Bool, Exception, String)`

    safely call any function, while forwarding any exception that may have occurred
    """
    function safe_call(f::Function, args...)

        res::Any = undef

        backtrace::String = ""
        exception_occurred::Bool = false
        exception::Union{Exception, UndefInitializer} = undef

        try
            res = f(args...)
        catch e
            exception = e
            backtrace = sprint(Base.showerror, exception, catch_backtrace())
            exception_occurred = true
        end

        return (res, exception_occurred, exception, backtrace)
    end

    """
    `dot(::Array, field::Symbol) -> Any`

    wrapped dot operator
    """
    function dot(x::Array, field_name::Symbol) ::Any

        index_maybe = parse(Int, string(field_name));
        @assert index_maybe isa Integer
        return x[index_maybe];
    end
    export dot;

    """
    `dot(::Module, field::Symbol) -> Any`

    wrapped dot operator
    """
    dot(x::Module, field_name::Symbol) = return x.eval(field_name);

    """
    `dot(x::Any, field::Symbol) -> Any`

    wrapped dot operator, x.field
    """
    dot(x::Any, field_name::Symbol) = return eval(:($x.$field_name))

    """
    `unroll_type(::Type) -> Type`

    unroll type declaration
    """
    function unroll_type(type::Type) ::Type

        while hasproperty(type, :body)
            type = type.body
        end

        return type
    end

    """
    `is_name_typename(::Type, ::Type) -> Bool`

    unroll type declaration, then check if name is typename
    """
    function is_name_typename(type_in::Type, type_comparison::Type) ::Bool
        return getproperty(type_in, :name) == Base.typename(type_comparison)
    end

    """
    `get_n_fields(::Type) -> Int64`
    """
    function get_n_fields(type::Type) ::Int64
        return length(fieldnames(type))
    end

    """
    `get_fields(::Type) -> Vector{Pair{Symbol, Type}}`

    get field symbols and types, used by jluna::Type::get_fields
    """
    function get_fields(type::Type) ::Vector{Pair{Symbol, Type}}

        out = Vector{Pair{Symbol, Type}}();
        names = fieldnames(type)
        types = fieldtypes(type)

        for i in 1:(length(names))
            push!(out, names[i] => types[i])
        end

        return out
    end

    """
    `get_parameter(::Type) -> Vector{Pair{Symbol, Type}}`

    get parameter symbols and upper type limits, used by jluna::Type::get_parameters
    """
    function get_parameters(type::Type) ::Vector{Pair{Symbol, Type}}

        while !hasproperty(type, :parameters)
            type = type.body
        end

        out = Vector{Pair{Symbol, Type}}();
        parameters = getproperty(type, :parameters)

        for i in 1:(length(parameters))
            push!(out, parameters[i].name => parameters[i].ub)
        end

        return out
    end

    """
    `get_n_parameters(::Type) -> Int64`
    """
    function get_n_parameters(type::Type) ::Int64

        type = unroll_type(type)

        return length(getproperty(type, :parameters))
    end

    """
    `assign_in_module(::Module, ::Symbol, ::T) -> T`

    assign variable in other module, throws if variable does not exist
    """
    function assign_in_module(m::Module, variable_name::Symbol, value::T) ::T where T

        if (!isdefined(m, variable_name))
            throw(UndefVarError(Symbol(string(m) * "." * string(variable_name))))
        end

        return Base.eval(m, :($variable_name = $value))
    end

    """
    `create_in_module(::Module, ::Symbol, ::T) -> T`

    assign variable in other module, if variable does not exist, create then assign
    """
    function create_or_assign_in_module(m::Module, variable_name::Symbol, value::T) ::T where T
        return Base.eval(m, :($variable_name = $value))
    end

    """
    `get_names(::Module) -> IdDict{Symbol, Any}`

    access all module members as dict
    """
    function get_names(m::Module) ::IdDict{Symbol, Any}

        out = IdDict{Symbol, Any}()

        for n in names(m; all = true)
            if string(n)[1] != '#'
                out[n] = m.eval(n)
            end
        end

        return out
    end

    """
    `get_nth_method(::Function, ::Integer) -> Method`

    wrap method access, used by jlune::Method
    """
    function get_nth_method(f::Function, i::Integer) ::Method

        return methods(f)[i]
    end

    """
    `get_return_type_of_nth_method(::Function, ::Integer) -> Type`

    used by jluna::Function to deduce method signature
    """
    function get_return_type_of_nth_method(f::Function, i::Integer) ::Type

        return Base.return_types(test)[i]
    end

    """
    `get_argument_type_of_nths_methods(::Function, ::Integer) -> Vector{Type}`

    used by jluna::Function to deduce method signature
    """
    function get_argument_types_of_nth_method(f::Function, i::Integer) ::Vector{Type}

        out = Vector{Type}()
        types = methods(f)[i].sig.types

        for i in 2:length(types)
            push!(out, types[i])
        end

        return out
    end


    """
    `get_length_of_generator(::Base.Generator) -> Int64`

    deduce length of Base.Generator object
    """
    function get_length_of_generator(gen::Base.Generator) ::Int64

        if (Base.haslength(gen))
            return length(gen)
        else
            # heuristically deduce length
            for i in Iterators.reverse(gen.iter.itr)
                if gen.iter.flt(i)
                    return i
                end
            end
        end
    end

    """
    `new_array(::Type, dims::Int64...) -> Array{Type, length(dims))`
    """
    function new_array(value_type::Type, lengths::Int64...)

        length = 1;
        for i in lengths
            length *= i
        end

        out = Array{value_type, 1}(undef, length)
        return reshape(out, lengths...)
    end

    """
    `get_value_type_of_array(::Array{T}) -> Type`

    forward value type of array
    """
    function get_value_type_of_array(_::Array{T}) ::Type where T

        return T
    end

    """
    `new_vector(::Integer, ::T) -> Vector{T}`

    create vector by deducing argument type
    """
    function new_vector(size::Integer, _::T) where T
        return Vector{T}(undef, size)
    end

    """
    `new_vector(::Integer, ::T) -> Vector{T}`

    create vector by deducing argument type
    """
    function new_vector(size::Integer, type::Type)
        return Vector{type}(undef, size)
    end

    """
    `new_complex(:T, :T) -> Complex{T}`

    wrap complex ctor
    """
    function new_complex(real::T, imag::T) ::Complex{T} where T
        return Complex{T}(real, imag)
    end

    """
    `invoke(function::Any, arguments::Any...) -> Any`

    wrap function call for non-function objects
    """
    function invoke(x::Any, args...) ::Any
        return x(args...)
    end

    """
    `create_or_assign(::Symbol, ::T) -> T`

    assign variable in main, or if none exist, create it and assign
    """
    function create_or_assign(symbol::Symbol, value::T) ::T where T

        return Main.eval(Expr(:(=), symbol, value))
    end

    """
    `serialize(<:AbstractDict{T, U}) -> Vector{Pair{T, U}}`

    transform dict into array
    """
    function serialize(x::T) ::Vector{Pair{Key_t, Value_t}} where {Key_t, Value_t, T <: AbstractDict{Key_t, Value_t}}

        out = Vector{Pair{Key_t, Value_t}}()
        for e in x
            push!(out, e)
        end
        return out;
    end

    """
    `serialize(::Set{T}) -> Vector{T}`

    transform dict into array
    """
    function serialize(x::T) ::Vector{U} where {U, T <: AbstractSet{U}}

        out = Vector{U}()

        for e in x
            push!(out, e)
        end

        return out;
    end

    """
    `new_dict(key_t::Type, value_t::Type, ::Integer) -> Dict{key_t, value_t}`

    create new dict from type, also provides sizehint
    """
    function new_dict(key_t::Type, value_t::Type, sizehint_maybe::Integer = 0)

        out = Dict{key_t, value_t}();
        sizehint!(out, sizehint_maybe);
        return out;
    end


    """
    `new_set(::Type, ::Integer) -> Set`

    create new set from type, also provides sizehint
    """
    function new_set(value_t::Type, sizehint_maybe::Integer = 0)

        out = Set{value_t}();
        sizehint!(out, sizehint_maybe);
        return out;
    end


    """
    offers julia-side memory management for C++ jluna
    """
    module memory_handler

        const _current_id = Ref(UInt64(0)) # modified atomically through locks
        const _refs = Ref(Dict{UInt64, Base.RefValue{Any}}())
        const _ref_counter = Ref(Dict{UInt64, UInt64}())

        const _refs_lock = Base.ReentrantLock()
        const _refs_counter_lock = Base.ReentrantLock()

        const _ref_id_marker = '#'
        const _refs_expression = Meta.parse("jluna.memory_handler._refs[]")

        # proxy id that is actually an expression, the ID of topmodule Main is
        ProxyID = Union{Expr, Symbol, Nothing}

        # make as unnamed
        make_unnamed_proxy_id(id::UInt64) = return Expr(:ref, Expr(:ref, _refs_expression, id))

        # make as named with owner and symbol name
        make_named_proxy_id(id::Symbol, owner_id::ProxyID) ::ProxyID = return Expr(:(.), owner_id, QuoteNode(id))

        # make as named with main as owner and symbol name
        make_named_proxy_id(id::Symbol, owner_id::Nothing) ::ProxyID = return id

        # make as named with owner and array index name
        make_named_proxy_id(id::Number, owner_id::ProxyID) ::ProxyID = return Expr(:ref, owner_id, convert(Int64, id))

        # assign to proxy id
        function assign(new_value::T, name::ProxyID) where T

            if new_value isa Symbol || new_value isa Expr
                return Main.eval(Expr(:(=), name, QuoteNode(new_value)))
            else
                return Main.eval(Expr(:(=), name, new_value));
            end
        end

        # eval proxy id
        evaluate(name::ProxyID) ::Any = return Main.eval(name)
        evaluate(name::Symbol) ::Any = return Main.eval(:($name))

        """
        `get_name(::ProxyID) -> String`

        parse name from proxy id
        """
        function get_name(id::ProxyID) ::String

            if length(id.args) == 0
                return "Main"
            end

            current = id
            while current.args[1] isa Expr && length(current.args) >= 2

                if current.args[2] isa UInt64
                    current.args[2] = convert(Int64, current.args[2])
                end

                current = current.args[1]
            end

            out = string(id)
            reg = r"\Q((jluna.memory_handler._refs[])[\E(.*)\Q])[]\E"
            captures = match(reg, out)

            if captures != nothing
                out = replace(out, reg => "<unnamed function proxy #" * string(tryparse(Int64, captures.captures[1])) * ">")
            end

            return out;
        end

        get_name(::Nothing) ::String = return "Main"
        get_name(s::Symbol) ::String = return string(s)
        get_name(i::Integer) ::String = return "[" * string(i) * "]"

        """
        `print_refs() -> Nothing`

        pretty print _ref state, for debugging
        """
        function print_refs() ::Nothing

            println("jluna.memory_handler._refs: ");
            for e in _refs[]
                println("\t", Int64(e.first), " => ", e.second[], " (", typeof(e.second[]), ") ")
            end
        end

        """
        `create_reference(::UInt64, ::Any) -> UInt64`

        add reference to _refs
        """
        function create_reference(to_wrap::Any) ::UInt64

            lock(_refs_lock)
            lock(_refs_counter_lock)

            global _current_id[] += 1
            key::UInt64 = _current_id[];

            if (haskey(_refs[], key))
                _ref_counter[][key] += 1
            else
                _refs[][key] = Base.RefValue{Any}(to_wrap)
                _ref_counter[][key] = 1
            end

            unlock(_refs_lock)
            unlock(_refs_counter_lock)

            return key;
        end

        create_reference(_::Nothing) ::UInt64 = return 0

        """
        `set_reference(::UInt64, ::T) -> Nothing`

        update the value of a reference in _refs without adding a new entry or changing it's key, ref pointers C++ side stay valid
        """
        function set_reference(key::UInt64, new_value::T) ::Base.RefValue{Any} where T

            lock(_refs_lock)
            result = begin _refs[][key] = Base.RefValue{Any}(new_value) end
            unlock(_refs_lock)
            return result
        end

        """
        `get_reference(::Int64) -> Any`

        access reference in _refs
        """
        function get_reference(key::UInt64) ::Any

            if (key == 0)
                return nothing
            end

            lock(_refs_lock)
            result = _refs[][key]
            unlock(_refs_lock)
            return result
        end

        """
        `free_reference(::UInt64) -> Nothing`

        free reference from _refs
        """
        function free_reference(key::UInt64) ::Nothing

            if (key == 0)
                return nothing;
            end

            lock(_refs_lock)

            if _refs[][key][] isa Module
                unlock(_refs_lock)
                return
            end

            lock(_refs_counter_lock)
            global _ref_counter[][key] -= 1
            count::UInt64 = _ref_counter[][key]

            if (count == 0)
                delete!(_ref_counter[], key)
                delete!(_refs[], key)
            end

            unlock(_refs_lock)
            unlock(_refs_counter_lock)
            return nothing;
        end

        """
        `force_free() -> Nothing`

        immediately deallocate all C++-managed values
        """
        function force_free() ::Nothing

            lock(_refs_lock)
            lock(_refs_counter_lock)

            for k in keys(_refs)
                delete!(_refs[], k)
                delete!(_ref_counter[], k)
            end

            unlock(_refs_lock)
            unlock(_refs_counter_lock)
            return nothing;
        end
    end

    module _cppcall

        #const _c_adapter_path = "<call jluna::initialize to initialize this field>";

        """
        object that is callable like a function, but executes C++-side code
        """
        struct UnnamedFunctionProxy{NArgs}

            _native_handle::UInt64

            function UnnamedFunctionProxy{N}(id::UInt64) where N

                out = new{N}(id)
                finalizer(function (t::UnnamedFunctionProxy{N})
                    ccall((:free_function, _cppcall._library_name), Cvoid, (Csize_t, Csize_t), t._native_handle, 0)
                end, out);
            end
        end

        """
        `make_unnamed_function_proxy(::UInt64, n::UInt64) -> UnnamedFunctionProxy{n}`
        """
        make_unnamed_function_proxy(id::UInt64, n_args::UInt64) = return UnnamedFunctionProxy{n_args}(id)

        """
        `invoke_function(id::UInt64, n::UInt64) -> Ptr{Any}`
        """
        function invoke_function(id::UInt64, xs...)

        end

        # call operator for (void) -> Any
        function (f::UnnamedFunctionProxy{N})(xs...) where N

            n = length(xs...)

            if n == N == 0
                return unsafe_pointer_to_objref(invoke_function(f._native_handle));
            elseif n == N == 1
                return unsafe_pointer_to_objref(invoke_function(f._native_handle, xs[1]));
            elseif n == N == 2
                return unsafe_pointer_to_objref(invoke_function(f._native_handle, xs[1], xs[2]));
            elseif n == N == 3
                return unsafe_pointer_to_objref(invoke_function(f._native_handle, xs[1], xs[2], xs[3]));
            elseif N != 0 && N != 1 && N != 2 & N != 3
                return unsafe_pointer_to_objref(invoke_function(f._native_handle, xs...));
            else
                throw(ErrorException(
                    "MethodError: when trying to invoke unnamedFunctionProxy #" * string(_native_handle) *
                    ": wrong number of arguments. expected: " * string(N) * ", got: " * string(n)
                ))
            end
        end
    end
end

using Main.jluna;

"""
`cppall(::Symbol, ::Any...) -> Any`

Call a lambda registered via `jluna::State::register_function` using `xs...` as arguments.
After the C++-side function returns, return the resulting object
(or `nothing` if the C++ function returns `void`)

This function is not thread-safe and should not be used in a parallel context
"""
function cppcall(function_name::Symbol, xs...) ::Any

    return nothing;
end