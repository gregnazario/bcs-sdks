//go:build ignore

// Go BCS E2E Test Runner
//
// Reads test vectors from stdin, performs roundtrip serialization,
// and outputs results to stdout.
package main

import (
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"

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

func main() {
	inputData, err := io.ReadAll(os.Stdin)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading stdin: %v\n", err)
		os.Exit(1)
	}

	var vectors TestVectors
	if err := json.Unmarshal(inputData, &vectors); err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing JSON: %v\n", err)
		os.Exit(1)
	}

	output := TestVectors{
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

	outputJSON, err := json.MarshalIndent(output, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshaling JSON: %v\n", err)
		os.Exit(1)
	}

	fmt.Println(string(outputJSON))
}
