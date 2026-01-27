//go:build ignore

// Go BCS E2E Test Runner
//
// Reads test vectors from stdin, performs roundtrip serialization,
// and outputs results to stdout.
//
// Supports two modes:
// - Default: Roundtrip testing for correctness
// - Benchmark (--benchmark): Performance timing
package main

import (
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"math/big"
	"os"
	"sort"
	"strings"
	"time"

	"github.com/bcs-sdks/bcs-go/bcs"
)

type TestCase struct {
	Name   string      `json:"name"`
	Type   string      `json:"type"`
	Value  interface{} `json:"value"`
	BcsHex string      `json:"bcs_hex"`
	Note   string      `json:"note,omitempty"`
	Error  string      `json:"error,omitempty"`
}

type TestVectors struct {
	Version     string     `json:"version"`
	Description string     `json:"description"`
	Primitives  []TestCase `json:"primitives"`
	Strings     []TestCase `json:"strings"`
	Bytes       []TestCase `json:"bytes"`
	Options     []TestCase `json:"options"`
	Vectors     []TestCase `json:"vectors"`
	Structs     []TestCase `json:"structs"`
	Complex     []TestCase `json:"complex"`
}

func hexToBytes(h string) ([]byte, error) {
	return hex.DecodeString(h)
}

func bytesToHex(b []byte) string {
	return hex.EncodeToString(b)
}

func processTestCase(tc TestCase) TestCase {
	data, err := hexToBytes(tc.BcsHex)
	if err != nil {
		return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: fmt.Sprintf("hex decode error: %v", err)}
	}

	var resultHex string

	switch tc.Type {
	case "bool":
		d := bcs.NewDeserializer(data)
		value, err := d.ReadBool()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteBool(value)
		resultHex = bytesToHex(s.Bytes())

	case "u8":
		d := bcs.NewDeserializer(data)
		value, err := d.ReadU8()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteU8(value)
		resultHex = bytesToHex(s.Bytes())

	case "u16":
		d := bcs.NewDeserializer(data)
		value, err := d.ReadU16()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteU16(value)
		resultHex = bytesToHex(s.Bytes())

	case "u32":
		d := bcs.NewDeserializer(data)
		value, err := d.ReadU32()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteU32(value)
		resultHex = bytesToHex(s.Bytes())

	case "u64":
		d := bcs.NewDeserializer(data)
		value, err := d.ReadU64()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteU64(value)
		resultHex = bytesToHex(s.Bytes())

	case "u128":
		d := bcs.NewDeserializer(data)
		value, err := d.ReadU128()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteU128(value)
		resultHex = bytesToHex(s.Bytes())

	case "i8":
		d := bcs.NewDeserializer(data)
		value, err := d.ReadI8()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteI8(value)
		resultHex = bytesToHex(s.Bytes())

	case "i16":
		d := bcs.NewDeserializer(data)
		value, err := d.ReadI16()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteI16(value)
		resultHex = bytesToHex(s.Bytes())

	case "i32":
		d := bcs.NewDeserializer(data)
		value, err := d.ReadI32()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteI32(value)
		resultHex = bytesToHex(s.Bytes())

	case "i64":
		d := bcs.NewDeserializer(data)
		value, err := d.ReadI64()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteI64(value)
		resultHex = bytesToHex(s.Bytes())

	case "i128":
		d := bcs.NewDeserializer(data)
		value, err := d.ReadI128()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteI128(value)
		resultHex = bytesToHex(s.Bytes())

	case "string":
		d := bcs.NewDeserializer(data)
		value, err := d.ReadString()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteString(value)
		resultHex = bytesToHex(s.Bytes())

	case "bytes":
		d := bcs.NewDeserializer(data)
		value, err := d.ReadBytes()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteBytes(value)
		resultHex = bytesToHex(s.Bytes())

	case "fixed_bytes_32":
		d := bcs.NewDeserializer(data)
		value, err := d.ReadFixedBytes(32)
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteFixedBytes(value, 32)
		resultHex = bytesToHex(s.Bytes())

	case "option<u8>":
		d := bcs.NewDeserializer(data)
		hasValue, err := d.ReadBool()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		if hasValue {
			value, err := d.ReadU8()
			if err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			if err := d.CheckEnd(); err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			s.WriteBool(true)
			s.WriteU8(value)
		} else {
			if err := d.CheckEnd(); err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			s.WriteBool(false)
		}
		resultHex = bytesToHex(s.Bytes())

	case "option<u64>":
		d := bcs.NewDeserializer(data)
		hasValue, err := d.ReadBool()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		if hasValue {
			value, err := d.ReadU64()
			if err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			if err := d.CheckEnd(); err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			s.WriteBool(true)
			s.WriteU64(value)
		} else {
			if err := d.CheckEnd(); err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			s.WriteBool(false)
		}
		resultHex = bytesToHex(s.Bytes())

	case "option<bool>":
		d := bcs.NewDeserializer(data)
		hasValue, err := d.ReadBool()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		if hasValue {
			value, err := d.ReadBool()
			if err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			if err := d.CheckEnd(); err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			s.WriteBool(true)
			s.WriteBool(value)
		} else {
			if err := d.CheckEnd(); err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			s.WriteBool(false)
		}
		resultHex = bytesToHex(s.Bytes())

	case "option<string>":
		d := bcs.NewDeserializer(data)
		hasValue, err := d.ReadBool()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		if hasValue {
			value, err := d.ReadString()
			if err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			if err := d.CheckEnd(); err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			s.WriteBool(true)
			s.WriteString(value)
		} else {
			if err := d.CheckEnd(); err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			s.WriteBool(false)
		}
		resultHex = bytesToHex(s.Bytes())

	case "vector<u8>":
		d := bcs.NewDeserializer(data)
		length, err := d.ReadULEB128()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		values := make([]uint8, length)
		for i := uint32(0); i < length; i++ {
			v, err := d.ReadU8()
			if err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			values[i] = v
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteULEB128(uint32(len(values)))
		for _, v := range values {
			s.WriteU8(v)
		}
		resultHex = bytesToHex(s.Bytes())

	case "vector<u64>":
		d := bcs.NewDeserializer(data)
		length, err := d.ReadULEB128()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		values := make([]uint64, length)
		for i := uint32(0); i < length; i++ {
			v, err := d.ReadU64()
			if err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			values[i] = v
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteULEB128(uint32(len(values)))
		for _, v := range values {
			s.WriteU64(v)
		}
		resultHex = bytesToHex(s.Bytes())

	case "vector<bool>":
		d := bcs.NewDeserializer(data)
		length, err := d.ReadULEB128()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		values := make([]bool, length)
		for i := uint32(0); i < length; i++ {
			v, err := d.ReadBool()
			if err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			values[i] = v
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteULEB128(uint32(len(values)))
		for _, v := range values {
			s.WriteBool(v)
		}
		resultHex = bytesToHex(s.Bytes())

	case "vector<vector<u8>>":
		d := bcs.NewDeserializer(data)
		outerLen, err := d.ReadULEB128()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		outer := make([][]uint8, outerLen)
		for i := uint32(0); i < outerLen; i++ {
			innerLen, err := d.ReadULEB128()
			if err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			inner := make([]uint8, innerLen)
			for j := uint32(0); j < innerLen; j++ {
				v, err := d.ReadU8()
				if err != nil {
					return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
				}
				inner[j] = v
			}
			outer[i] = inner
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteULEB128(uint32(len(outer)))
		for _, inner := range outer {
			s.WriteULEB128(uint32(len(inner)))
			for _, v := range inner {
				s.WriteU8(v)
			}
		}
		resultHex = bytesToHex(s.Bytes())

	case "vector<string>":
		d := bcs.NewDeserializer(data)
		length, err := d.ReadULEB128()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		values := make([]string, length)
		for i := uint32(0); i < length; i++ {
			v, err := d.ReadString()
			if err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			values[i] = v
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteULEB128(uint32(len(values)))
		for _, v := range values {
			s.WriteString(v)
		}
		resultHex = bytesToHex(s.Bytes())

	case "struct":
		valueMap, ok := tc.Value.(map[string]interface{})
		if !ok {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: "invalid struct value"}
		}
		fieldsInterface, ok := valueMap["fields"].([]interface{})
		if !ok {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: "invalid struct fields"}
		}

		d := bcs.NewDeserializer(data)
		s := bcs.NewSerializer()

		for _, fi := range fieldsInterface {
			field, ok := fi.(map[string]interface{})
			if !ok {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: "invalid field"}
			}
			fieldType, ok := field["type"].(string)
			if !ok {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: "invalid field type"}
			}

			switch fieldType {
			case "u8":
				v, err := d.ReadU8()
				if err != nil {
					return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
				}
				s.WriteU8(v)
			case "u64":
				v, err := d.ReadU64()
				if err != nil {
					return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
				}
				s.WriteU64(v)
			case "string":
				v, err := d.ReadString()
				if err != nil {
					return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
				}
				s.WriteString(v)
			case "fixed_bytes_32":
				v, err := d.ReadFixedBytes(32)
				if err != nil {
					return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
				}
				s.WriteFixedBytes(v, 32)
			default:
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: fmt.Sprintf("unknown field type: %s", fieldType)}
			}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		resultHex = bytesToHex(s.Bytes())

	case "map<u8,u8>":
		d := bcs.NewDeserializer(data)
		length, err := d.ReadULEB128()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		pairs := make([][2]uint8, length)
		for i := uint32(0); i < length; i++ {
			k, err := d.ReadU8()
			if err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			v, err := d.ReadU8()
			if err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			pairs[i] = [2]uint8{k, v}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteULEB128(uint32(len(pairs)))
		for _, p := range pairs {
			s.WriteU8(p[0])
			s.WriteU8(p[1])
		}
		resultHex = bytesToHex(s.Bytes())

	case "map<string,u64>":
		d := bcs.NewDeserializer(data)
		length, err := d.ReadULEB128()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		type pair struct {
			k string
			v uint64
		}
		pairs := make([]pair, length)
		for i := uint32(0); i < length; i++ {
			k, err := d.ReadString()
			if err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			v, err := d.ReadU64()
			if err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			pairs[i] = pair{k, v}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteULEB128(uint32(len(pairs)))
		for _, p := range pairs {
			s.WriteString(p.k)
			s.WriteU64(p.v)
		}
		resultHex = bytesToHex(s.Bytes())

	case "tuple<u8,u64>":
		d := bcs.NewDeserializer(data)
		a, err := d.ReadU8()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		b, err := d.ReadU64()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteU8(a)
		s.WriteU64(b)
		resultHex = bytesToHex(s.Bytes())

	case "vector<option<u8>>":
		d := bcs.NewDeserializer(data)
		length, err := d.ReadULEB128()
		if err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		type optU8 struct {
			hasValue bool
			value    uint8
		}
		values := make([]optU8, length)
		for i := uint32(0); i < length; i++ {
			hasValue, err := d.ReadBool()
			if err != nil {
				return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
			}
			if hasValue {
				v, err := d.ReadU8()
				if err != nil {
					return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
				}
				values[i] = optU8{true, v}
			} else {
				values[i] = optU8{false, 0}
			}
		}
		if err := d.CheckEnd(); err != nil {
			return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: err.Error()}
		}
		s := bcs.NewSerializer()
		s.WriteULEB128(uint32(len(values)))
		for _, opt := range values {
			if opt.hasValue {
				s.WriteBool(true)
				s.WriteU8(opt.value)
			} else {
				s.WriteBool(false)
			}
		}
		resultHex = bytesToHex(s.Bytes())

	default:
		return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, Error: fmt.Sprintf("unknown type: %s", tc.Type)}
	}

	return TestCase{Name: tc.Name, Type: tc.Type, Value: tc.Value, BcsHex: resultHex}
}

func processCases(cases []TestCase) []TestCase {
	results := make([]TestCase, len(cases))
	for i, tc := range cases {
		results[i] = processTestCase(tc)
	}
	return results
}

// Benchmark types and functions

type BenchmarkSpec struct {
	Version   string                     `json:"version"`
	Config    BenchmarkConfig            `json:"config"`
	Scenarios map[string]BenchmarkGroup  `json:"scenarios"`
}

type BenchmarkConfig struct {
	DefaultIterations int `json:"default_iterations"`
	WarmupIterations  int `json:"warmup_iterations"`
}

type BenchmarkGroup struct {
	Description string           `json:"description"`
	Benchmarks  []BenchmarkCase  `json:"benchmarks"`
}

type BenchmarkCase struct {
	Name           string      `json:"name"`
	Type           string      `json:"type"`
	Value          interface{} `json:"value"`
	ValueGenerator string      `json:"value_generator"`
	Length         int         `json:"length"`
	Char           string      `json:"char"`
	Iterations     int         `json:"iterations"`
}

type BenchmarkResult struct {
	Name                       string  `json:"name"`
	Type                       string  `json:"type"`
	Iterations                 int     `json:"iterations"`
	SerializeAvgNs             float64 `json:"serialize_avg_ns"`
	SerializeMinNs             float64 `json:"serialize_min_ns"`
	SerializeMaxNs             float64 `json:"serialize_max_ns"`
	SerializeP50Ns             float64 `json:"serialize_p50_ns"`
	SerializeP95Ns             float64 `json:"serialize_p95_ns"`
	DeserializeAvgNs           float64 `json:"deserialize_avg_ns"`
	DeserializeMinNs           float64 `json:"deserialize_min_ns"`
	DeserializeMaxNs           float64 `json:"deserialize_max_ns"`
	DeserializeP50Ns           float64 `json:"deserialize_p50_ns"`
	DeserializeP95Ns           float64 `json:"deserialize_p95_ns"`
	ThroughputSerializeOpsSec  float64 `json:"throughput_serialize_ops_sec"`
	ThroughputDeserializeOpsSec float64 `json:"throughput_deserialize_ops_sec"`
	Error                      string  `json:"error,omitempty"`
}

type BenchmarkOutput struct {
	Version     string            `json:"version"`
	Description string            `json:"description"`
	Benchmarks  []BenchmarkResult `json:"benchmarks"`
}

func computeStats(times []int64) (avg, min, max, p50, p95 float64) {
	if len(times) == 0 {
		return 0, 0, 0, 0, 0
	}

	sorted := make([]int64, len(times))
	copy(sorted, times)
	sort.Slice(sorted, func(i, j int) bool { return sorted[i] < sorted[j] })

	n := len(sorted)
	var sum int64
	for _, t := range sorted {
		sum += t
	}

	avg = float64(sum) / float64(n)
	min = float64(sorted[0])
	max = float64(sorted[n-1])
	p50 = float64(sorted[n/2])
	p95Idx := int(float64(n) * 0.95)
	if p95Idx >= n {
		p95Idx = n - 1
	}
	p95 = float64(sorted[p95Idx])

	return avg, min, max, p50, p95
}

func generateValue(bc BenchmarkCase) interface{} {
	if bc.Value != nil {
		return bc.Value
	}

	length := bc.Length
	if length == 0 {
		length = 10
	}

	switch bc.ValueGenerator {
	case "repeat_char":
		char := bc.Char
		if char == "" {
			char = "a"
		}
		return strings.Repeat(char, length)
	case "sequential_bytes", "sequential_u8":
		// Return as []interface{} for consistency with JSON parsing
		result := make([]interface{}, length)
		for i := 0; i < length; i++ {
			result[i] = float64(i % 256)
		}
		return result
	case "sequential_u64":
		result := make([]interface{}, length)
		for i := 0; i < length; i++ {
			result[i] = fmt.Sprintf("%d", i)
		}
		return result
	case "address_bytes":
		result := make([]interface{}, 32)
		for i := 0; i < 31; i++ {
			result[i] = float64(0)
		}
		result[31] = float64(1)
		return result
	}

	return bc.Value
}

func serializeValue(s *bcs.Serializer, typ string, value interface{}) error {
	switch typ {
	case "bool":
		s.WriteBool(value.(bool))
	case "u8":
		v := int(value.(float64))
		s.WriteU8(uint8(v))
	case "u16":
		v := int(value.(float64))
		s.WriteU16(uint16(v))
	case "u32":
		v := int64(value.(float64))
		s.WriteU32(uint32(v))
	case "u64":
		var v uint64
		switch val := value.(type) {
		case string:
			bi := new(big.Int)
			bi.SetString(val, 10)
			v = bi.Uint64()
		case float64:
			v = uint64(val)
		}
		s.WriteU64(v)
	case "u128":
		var str string
		switch val := value.(type) {
		case string:
			str = val
		case float64:
			str = fmt.Sprintf("%.0f", val)
		}
		bi := new(big.Int)
		bi.SetString(str, 10)
		s.WriteU128(bi)
	case "i8":
		v := int(value.(float64))
		s.WriteI8(int8(v))
	case "i16":
		v := int(value.(float64))
		s.WriteI16(int16(v))
	case "i32":
		v := int64(value.(float64))
		s.WriteI32(int32(v))
	case "i64":
		var v int64
		switch val := value.(type) {
		case string:
			bi := new(big.Int)
			bi.SetString(val, 10)
			v = bi.Int64()
		case float64:
			v = int64(val)
		}
		s.WriteI64(v)
	case "i128":
		var str string
		switch val := value.(type) {
		case string:
			str = val
		case float64:
			str = fmt.Sprintf("%.0f", val)
		}
		bi := new(big.Int)
		bi.SetString(str, 10)
		s.WriteI128(bi)
	case "string":
		s.WriteString(value.(string))
	case "bytes":
		arr := value.([]interface{})
		data := make([]byte, len(arr))
		for i, v := range arr {
			data[i] = byte(v.(float64))
		}
		s.WriteBytes(data)
	case "fixed_bytes":
		arr := value.([]interface{})
		data := make([]byte, len(arr))
		for i, v := range arr {
			data[i] = byte(v.(float64))
		}
		s.WriteFixedBytes(data, len(data))
	case "vector<u8>":
		arr := value.([]interface{})
		s.WriteULEB128(uint32(len(arr)))
		for _, v := range arr {
			s.WriteU8(uint8(v.(float64)))
		}
	case "vector<u64>":
		arr := value.([]interface{})
		s.WriteULEB128(uint32(len(arr)))
		for _, v := range arr {
			var val uint64
			switch vv := v.(type) {
			case string:
				bi := new(big.Int)
				bi.SetString(vv, 10)
				val = bi.Uint64()
			case float64:
				val = uint64(vv)
			}
			s.WriteU64(val)
		}
	case "vector<string>":
		arr := value.([]interface{})
		s.WriteULEB128(uint32(len(arr)))
		for _, v := range arr {
			s.WriteString(v.(string))
		}
	default:
		return fmt.Errorf("unknown type: %s", typ)
	}
	return nil
}

func deserializeValue(d *bcs.Deserializer, typ string) (interface{}, error) {
	switch typ {
	case "bool":
		return d.ReadBool()
	case "u8":
		return d.ReadU8()
	case "u16":
		return d.ReadU16()
	case "u32":
		return d.ReadU32()
	case "u64":
		return d.ReadU64()
	case "u128":
		return d.ReadU128()
	case "i8":
		return d.ReadI8()
	case "i16":
		return d.ReadI16()
	case "i32":
		return d.ReadI32()
	case "i64":
		return d.ReadI64()
	case "i128":
		return d.ReadI128()
	case "string":
		return d.ReadString()
	case "bytes":
		return d.ReadBytes()
	case "fixed_bytes":
		return d.ReadFixedBytes(32)
	case "vector<u8>":
		length, err := d.ReadULEB128()
		if err != nil {
			return nil, err
		}
		result := make([]uint8, length)
		for i := uint32(0); i < length; i++ {
			v, err := d.ReadU8()
			if err != nil {
				return nil, err
			}
			result[i] = v
		}
		return result, nil
	case "vector<u64>":
		length, err := d.ReadULEB128()
		if err != nil {
			return nil, err
		}
		result := make([]uint64, length)
		for i := uint32(0); i < length; i++ {
			v, err := d.ReadU64()
			if err != nil {
				return nil, err
			}
			result[i] = v
		}
		return result, nil
	case "vector<string>":
		length, err := d.ReadULEB128()
		if err != nil {
			return nil, err
		}
		result := make([]string, length)
		for i := uint32(0); i < length; i++ {
			v, err := d.ReadString()
			if err != nil {
				return nil, err
			}
			result[i] = v
		}
		return result, nil
	default:
		return nil, fmt.Errorf("unknown type: %s", typ)
	}
}

func runBenchmark(spec BenchmarkSpec) BenchmarkOutput {
	output := BenchmarkOutput{
		Version:     spec.Version,
		Description: "Go benchmark results",
		Benchmarks:  []BenchmarkResult{},
	}

	defaultIterations := spec.Config.DefaultIterations
	if defaultIterations == 0 {
		defaultIterations = 1000
	}
	warmup := spec.Config.WarmupIterations
	if warmup == 0 {
		warmup = 10
	}

	for _, group := range spec.Scenarios {
		for _, bc := range group.Benchmarks {
			iterations := bc.Iterations
			if iterations == 0 {
				iterations = defaultIterations
			}

			value := generateValue(bc)
			if value == nil {
				output.Benchmarks = append(output.Benchmarks, BenchmarkResult{
					Name:       bc.Name,
					Type:       bc.Type,
					Iterations: iterations,
					Error:      "could not generate value",
				})
				continue
			}

			// Serialize to get bytes for deserialize benchmark
			s := bcs.NewSerializer()
			if err := serializeValue(s, bc.Type, value); err != nil {
				output.Benchmarks = append(output.Benchmarks, BenchmarkResult{
					Name:       bc.Name,
					Type:       bc.Type,
					Iterations: iterations,
					Error:      err.Error(),
				})
				continue
			}
			bcsBytes := s.Bytes()

			// Warmup serialize
			for i := 0; i < warmup; i++ {
				ws := bcs.NewSerializer()
				serializeValue(ws, bc.Type, value)
				_ = ws.Bytes()
			}

			// Benchmark serialize
			serTimes := make([]int64, iterations)
			for i := 0; i < iterations; i++ {
				start := time.Now()
				bs := bcs.NewSerializer()
				serializeValue(bs, bc.Type, value)
				_ = bs.Bytes()
				serTimes[i] = time.Since(start).Nanoseconds()
			}

			// Warmup deserialize
			for i := 0; i < warmup; i++ {
				wd := bcs.NewDeserializer(bcsBytes)
				deserializeValue(wd, bc.Type)
			}

			// Benchmark deserialize
			deTimes := make([]int64, iterations)
			for i := 0; i < iterations; i++ {
				start := time.Now()
				bd := bcs.NewDeserializer(bcsBytes)
				deserializeValue(bd, bc.Type)
				deTimes[i] = time.Since(start).Nanoseconds()
			}

			serAvg, serMin, serMax, serP50, serP95 := computeStats(serTimes)
			deAvg, deMin, deMax, deP50, deP95 := computeStats(deTimes)

			serThroughput := 0.0
			if serAvg > 0 {
				serThroughput = 1_000_000_000.0 / serAvg
			}
			deThroughput := 0.0
			if deAvg > 0 {
				deThroughput = 1_000_000_000.0 / deAvg
			}

			output.Benchmarks = append(output.Benchmarks, BenchmarkResult{
				Name:                        bc.Name,
				Type:                        bc.Type,
				Iterations:                  iterations,
				SerializeAvgNs:              serAvg,
				SerializeMinNs:              serMin,
				SerializeMaxNs:              serMax,
				SerializeP50Ns:              serP50,
				SerializeP95Ns:              serP95,
				DeserializeAvgNs:            deAvg,
				DeserializeMinNs:            deMin,
				DeserializeMaxNs:            deMax,
				DeserializeP50Ns:            deP50,
				DeserializeP95Ns:            deP95,
				ThroughputSerializeOpsSec:   serThroughput,
				ThroughputDeserializeOpsSec: deThroughput,
			})
		}
	}

	return output
}

func runRoundtrip(vectors TestVectors) TestVectors {
	return TestVectors{
		Version:     vectors.Version,
		Description: "Go roundtrip results",
		Primitives:  processCases(vectors.Primitives),
		Strings:     processCases(vectors.Strings),
		Bytes:       processCases(vectors.Bytes),
		Options:     processCases(vectors.Options),
		Vectors:     processCases(vectors.Vectors),
		Structs:     processCases(vectors.Structs),
		Complex:     processCases(vectors.Complex),
	}
}

func main() {
	benchmarkMode := flag.Bool("benchmark", false, "Run benchmarks instead of correctness tests")
	flag.Parse()

	inputData, err := io.ReadAll(os.Stdin)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading stdin: %v\n", err)
		os.Exit(1)
	}

	var outputJSON []byte

	if *benchmarkMode {
		var spec BenchmarkSpec
		if err := json.Unmarshal(inputData, &spec); err != nil {
			fmt.Fprintf(os.Stderr, "Error parsing JSON: %v\n", err)
			os.Exit(1)
		}
		output := runBenchmark(spec)
		outputJSON, err = json.MarshalIndent(output, "", "  ")
	} else {
		var vectors TestVectors
		if err := json.Unmarshal(inputData, &vectors); err != nil {
			fmt.Fprintf(os.Stderr, "Error parsing JSON: %v\n", err)
			os.Exit(1)
		}
		output := runRoundtrip(vectors)
		outputJSON, err = json.MarshalIndent(output, "", "  ")
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshaling JSON: %v\n", err)
		os.Exit(1)
	}

	fmt.Println(string(outputJSON))
}
