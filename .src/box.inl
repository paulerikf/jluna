// 
// Copyright 2022 Clemens Cords
// Created on 31.01.22 by clem (mail@clemens-cords.com)
//

#include <include/cppcall.hpp>

#include <iostream>


namespace jluna
{
    template<IsJuliaValuePointer T>
    unsafe::Value* box(T value)
    {
        return (unsafe::Value*) value;
    }

    template<Is<bool> T>
    unsafe::Value* box(T value)
    {
        return jl_box_bool(value);
    }

    template<Is<std::bool_constant<true>> T>
    unsafe::Value* box(T value)
    {
        return jl_box_bool(true);
    }

    template<Is<std::bool_constant<false>> T>
    unsafe::Value* box(T value)
    {
        return jl_box_bool(false);
    }
    
    template<Is<char> T>
    unsafe::Value* box(T value)
    {
        return detail::convert(jl_char_type, jl_box_int8((int8_t) value));
    }

    template<Is<uint8_t> T>
    unsafe::Value* box(T value)
    {
        return jl_box_uint8((uint8_t) value);
    }

    template<Is<uint16_t> T>
    unsafe::Value* box(T value)
    {
        return jl_box_uint16((uint16_t) value);
    }

    template<Is<uint32_t> T>
    unsafe::Value* box(T value)
    {
        return jl_box_uint32((uint32_t) value);
    }

    template<Is<uint64_t> T>
    unsafe::Value* box(T value)
    {
        return jl_box_uint64((uint64_t) value);
    }

    template<Is<int8_t> T>
    unsafe::Value* box(T value)
    {
        return jl_box_int8((int8_t) value);
    }

    template<Is<int16_t> T>
    unsafe::Value* box(T value)
    {
        return jl_box_int16((int16_t) value);
    }

    template<Is<int32_t> T>
    unsafe::Value* box(T value)
    {
        return jl_box_int32((int32_t) value);
    }

    template<Is<int64_t> T>
    unsafe::Value* box(T value)
    {
        return jl_box_int64((int64_t) value);
    }

    template<Is<float> T>
    unsafe::Value* box(T value)
    {
        return jl_box_float32((float) value);
    }

    template<Is<double> T>
    unsafe::Value* box(T value)
    {
        return jl_box_float64((double) value);
    }

    template<Is<std::string> T>
    unsafe::Value* box(T value)
    {
        auto gc = GCSentinel();
        auto* array = unsafe::new_array_from_data((unsafe::Value*) to_julia_type<char>::type(), value.data(), value.size());
        return jl_array_to_string(array);
    }

    template<Is<const char*> T>
    unsafe::Value* box(T value)
    {
        auto gc = GCSentinel();
        std::string as_string = value;
        auto* array = unsafe::new_array_from_data((unsafe::Value*) to_julia_type<char>::type(), as_string.data(), as_string.size());
        return jl_array_to_string(array);
    }

    template<typename T, typename Value_t, std::enable_if_t<std::is_same_v<T, std::complex<Value_t>>, bool>>
    unsafe::Value* box(T value)
    {
        static jl_function_t* complex = unsafe::get_function("jluna"_sym, "make_complex"_sym);
        return safe_call(complex, box<Value_t>(value.real()), box<Value_t>(value.imag()));
    }

    template<typename T, typename Value_t, std::enable_if_t<std::is_same_v<T, std::vector<Value_t>>, bool>>
    unsafe::Value* box(const T& value)
    {
        return unsafe::new_array_from_data(to_julia_type<Value_t>::type(), value.data(), value.size());
    }

    template<typename T, typename Key_t, typename Value_t, std::enable_if_t<
            std::is_same_v<T, std::unordered_map<Key_t, Value_t>> or
            std::is_same_v<T, std::map<Key_t, Value_t>>,
            bool>>
    unsafe::Value* box(T value)
    {
        static auto* new_dict = unsafe::get_function("jluna"_sym, "new_dict"_sym);
        static auto* setindex = unsafe::get_function(jl_base_module, "setindex!"_sym);

        auto gc = GCSentinel();

        auto* out = unsafe::call(new_dict, to_julia_type<Key_t>::type(), to_julia_type<Value_t>::type(), value.size());
        for (auto& pair : value)
            unsafe::call(setindex, box<Value_t>(pair.second), box<Key_t>(pair.first));

        return out;
    }

    template<typename T, typename Value_t, std::enable_if_t<std::is_same_v<T, std::set<Value_t>>, bool>>
    unsafe::Value* box(const T& value)
    {
        static auto* new_set = unsafe::get_function("jluna"_sym, "new_set"_sym);
        static auto* push = unsafe::get_function(jl_base_module, "push!"_sym);
        auto gc = GCSentinel();
        auto* out = unsafe::call(new_set, to_julia_type<Value_t>::type(), value.size());

        for (auto& e : value)
            unsafe::call(push, out, box<Value_t>(e));

        return out;
    }

    template<typename T, typename T1, typename T2, std::enable_if_t<std::is_same_v<T, std::pair<T1, T2>>, bool>>
    unsafe::Value* box(T value)
    {
        return jl_new_struct(jl_pair_type, box<T1>(value.first), box<T2>(value.second));
    }

    template<IsTuple T>
    unsafe::Value* box(T value)
    {
        auto gc = GCSentinel();

        std::vector<unsafe::Value*> args;
        args.reserve(std::tuple_size_v<T>);

        std::apply([&](auto... elements) {
            (args.push_back(box<decltype(elements)>(elements)), ...);
        }, value);

        auto tuple_t = jl_apply_tuple_type_v(args.data(), args.size());
        return jl_new_structv(tuple_t, args.data(), args.size());
    }

    template<LambdaType<> T>
    unsafe::Value* box(T lambda)
    {
        return register_unnamed_function<T>(lambda);
    }

    template<LambdaType<unsafe::Value*> T>
    unsafe::Value* box(T lambda)
    {
        return register_unnamed_function<T>(lambda);
    }

    template<LambdaType<unsafe::Value*, unsafe::Value*> T>
    unsafe::Value* box(T lambda)
    {
        return register_unnamed_function<T>(lambda);
    }

    template<LambdaType<unsafe::Value*, unsafe::Value*, unsafe::Value*> T>
    unsafe::Value* box(T lambda)
    {
        return register_unnamed_function<T>(lambda);
    }

    template<LambdaType<unsafe::Value*, unsafe::Value*, unsafe::Value*, unsafe::Value*> T>
    unsafe::Value* box(T lambda)
    {
        return register_unnamed_function<T>(lambda);
    }

    template<LambdaType<std::vector<unsafe::Value*>> T>
    unsafe::Value* box(T lambda)
    {
        return register_unnamed_function<T>(lambda);
    }
}