// 
// Copyright 2022 Clemens Cords
// Created on 30.01.22 by clem (mail@clemens-cords.com)
//

#include <include/exceptions.hpp>
#include <include/julia_extension.hpp>
#include <include/unsafe_utilities.hpp>

#include <sstream>
#include <vector>
#include <iostream>

namespace jluna
{
    JuliaException::JuliaException(jl_value_t* exception, std::string stacktrace)
        : _value(exception), _message("[JULIA][EXCEPTION] " + stacktrace)
    {}

    const char* JuliaException::what() const noexcept
    {
        return _message.c_str();
    }

    JuliaException::operator unsafe::Value*()
    {
        return _value;
    }

    JuliaUninitializedException::JuliaUninitializedException()
        : std::exception()
    {}

    const char * JuliaUninitializedException::what() const noexcept
    {
        return "[C++][ERROR] jluna and julia need to be initialized using jluna::initialize() before usage";
    }

    void throw_if_uninitialized()
    {
        static bool initialized = false;

        if (initialized)
            return;

        if (not jl_is_initialized())
            throw JuliaUninitializedException();
        else
            initialized = true;
    }

    void forward_last_exception()
    {
        throw_if_uninitialized();

        auto* exc = jl_exception_occurred();
        if (exc != nullptr)
            throw JuliaException(exc, jl_string_ptr(jl_get_nth_field(exc, 0)));
    }

    unsafe::Value* safe_eval(const std::string& code, unsafe::Module* module)
    {
        static auto* eval = unsafe::get_function(jl_base_module, "eval"_sym);

        auto* quote = jl_quote(code.c_str());
        if (quote == nullptr)
        {
            auto* exc = jl_exception_occurred();
            std::stringstream str;
            str << "In jluna::safe_eval: " << jl_typeof_str(exc) << " in expression\n\t" << code << "\n"
                << jl_string_ptr(jl_get_nth_field(exc, 0)) << std::endl;
            throw JuliaException(exc, str.str());
        }

        jl_set_nth_field(quote, 0, (unsafe::Value*) "toplevel"_sym);
        return safe_call(eval, module, quote);
    }

    unsafe::Value* operator""_eval(const char* str, size_t _)
    {
        return safe_eval(str);
    }
}

