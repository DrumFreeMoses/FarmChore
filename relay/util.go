package main

import (
	"encoding/json"
	"fmt"
	"strings"
)

func jsonMarshal(v any) ([]byte, error) { return json.Marshal(v) }

func jsonUnmarshal(data []byte, v any) error { return json.Unmarshal(data, v) }

func isUniqueViolation(err error) bool {
	return err != nil && strings.Contains(err.Error(), "UNIQUE constraint failed")
}

func inClause(column string, n int) string {
	placeholders := make([]string, n)
	for i := range placeholders {
		placeholders[i] = "?"
	}
	return fmt.Sprintf("%s IN (%s)", column, strings.Join(placeholders, ","))
}

func anySlice[T any](v []T) []any {
	out := make([]any, len(v))
	for i, s := range v {
		out[i] = s
	}
	return out
}

func join(parts []string, sep string) string { return strings.Join(parts, sep) }
