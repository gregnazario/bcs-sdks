// Package bcs provides Binary Canonical Serialization for Go.
package bcs

import (
	"errors"
	"fmt"
)

// ErrorType represents the type of BCS error.
type ErrorType int

const (
	// ErrUnexpectedEOF indicates unexpected end of input.
	ErrUnexpectedEOF ErrorType = iota
	// ErrInvalidBoolean indicates an invalid boolean value.
	ErrInvalidBoolean
	// ErrInvalidOption indicates an invalid option tag.
	ErrInvalidOption
	// ErrInvalidUTF8 indicates invalid UTF-8 encoding.
	ErrInvalidUTF8
	// ErrNonCanonicalULEB128 indicates non-canonical ULEB128 encoding.
	ErrNonCanonicalULEB128
	// ErrULEB128Overflow indicates ULEB128 value overflow.
	ErrULEB128Overflow
	// ErrExceededMaxLength indicates sequence length exceeded maximum.
	ErrExceededMaxLength
	// ErrExceededContainerDepth indicates container depth exceeded maximum.
	ErrExceededContainerDepth
	// ErrRemainingInput indicates unconsumed input after deserialization.
	ErrRemainingInput
	// ErrNonCanonicalMap indicates map keys not sorted.
	ErrNonCanonicalMap
	// ErrDuplicateMapKey indicates duplicate key in map.
	ErrDuplicateMapKey
	// ErrUnknownVariant indicates an unknown enum variant index.
	ErrUnknownVariant
	// ErrNotSupported indicates an unsupported type.
	ErrNotSupported
	// ErrValueOutOfRange indicates a value outside the valid range.
	ErrValueOutOfRange
)

// Error represents a BCS serialization/deserialization error.
type Error struct {
	Type    ErrorType
	Message string
}

func (e *Error) Error() string {
	return e.Message
}

// Is implements error matching for errors.Is.
func (e *Error) Is(target error) bool {
	var bcsErr *Error
	if errors.As(target, &bcsErr) {
		return e.Type == bcsErr.Type
	}
	return false
}

// NewUnexpectedEOF creates an unexpected EOF error.
func NewUnexpectedEOF() *Error {
	return &Error{
		Type:    ErrUnexpectedEOF,
		Message: "unexpected end of input",
	}
}

// NewUnexpectedEOFWithDetails creates an unexpected EOF error with details.
func NewUnexpectedEOFWithDetails(expected, available int) *Error {
	return &Error{
		Type:    ErrUnexpectedEOF,
		Message: fmt.Sprintf("unexpected end of input: expected %d bytes, got %d", expected, available),
	}
}

// NewInvalidBoolean creates an invalid boolean error.
func NewInvalidBoolean(value byte) *Error {
	return &Error{
		Type:    ErrInvalidBoolean,
		Message: fmt.Sprintf("invalid boolean value: 0x%02x (expected 0x00 or 0x01)", value),
	}
}

// NewInvalidOption creates an invalid option error.
func NewInvalidOption(value byte) *Error {
	return &Error{
		Type:    ErrInvalidOption,
		Message: fmt.Sprintf("invalid option tag: 0x%02x (expected 0x00 or 0x01)", value),
	}
}

// NewInvalidUTF8 creates an invalid UTF-8 error.
func NewInvalidUTF8(reason string) *Error {
	if reason == "" {
		reason = "invalid UTF-8 encoding"
	}
	return &Error{
		Type:    ErrInvalidUTF8,
		Message: reason,
	}
}

// NewNonCanonicalULEB128 creates a non-canonical ULEB128 error.
func NewNonCanonicalULEB128() *Error {
	return &Error{
		Type:    ErrNonCanonicalULEB128,
		Message: "non-canonical ULEB128 encoding (trailing zero bytes)",
	}
}

// NewULEB128Overflow creates a ULEB128 overflow error.
func NewULEB128Overflow() *Error {
	return &Error{
		Type:    ErrULEB128Overflow,
		Message: "ULEB128 value overflow (exceeds u32 max)",
	}
}

// NewExceededMaxLength creates an exceeded max length error.
func NewExceededMaxLength(length uint64) *Error {
	return &Error{
		Type:    ErrExceededMaxLength,
		Message: fmt.Sprintf("sequence length %d exceeds maximum allowed (2^31 - 1)", length),
	}
}

// NewExceededContainerDepth creates an exceeded container depth error.
func NewExceededContainerDepth(container string) *Error {
	msg := "exceeded maximum container depth (500)"
	if container != "" {
		msg = fmt.Sprintf("exceeded maximum container depth (500) while entering %s", container)
	}
	return &Error{
		Type:    ErrExceededContainerDepth,
		Message: msg,
	}
}

// NewRemainingInput creates a remaining input error.
func NewRemainingInput(remaining int) *Error {
	return &Error{
		Type:    ErrRemainingInput,
		Message: fmt.Sprintf("remaining input after deserialization: %d bytes", remaining),
	}
}

// NewNonCanonicalMap creates a non-canonical map error.
func NewNonCanonicalMap() *Error {
	return &Error{
		Type:    ErrNonCanonicalMap,
		Message: "non-canonical map: keys not sorted",
	}
}

// NewDuplicateMapKey creates a duplicate map key error.
func NewDuplicateMapKey() *Error {
	return &Error{
		Type:    ErrDuplicateMapKey,
		Message: "duplicate key in map",
	}
}

// NewUnknownVariant creates an unknown variant error.
func NewUnknownVariant(index, maxIndex uint32) *Error {
	return &Error{
		Type:    ErrUnknownVariant,
		Message: fmt.Sprintf("unknown enum variant index: %d (max: %d)", index, maxIndex),
	}
}

// NewNotSupported creates a not supported error.
func NewNotSupported(typeName string) *Error {
	return &Error{
		Type:    ErrNotSupported,
		Message: fmt.Sprintf("type not supported: %s", typeName),
	}
}

// NewValueOutOfRange creates a value out of range error.
func NewValueOutOfRange(typeName string, value any) *Error {
	return &Error{
		Type:    ErrValueOutOfRange,
		Message: fmt.Sprintf("%s value out of range: %v", typeName, value),
	}
}
