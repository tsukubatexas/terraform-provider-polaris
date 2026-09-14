package provider

import (
	"fmt"
	"net/url"
	"regexp"
	"sort"
	"strings"

	"github.com/agext/levenshtein"
	"github.com/tsukubatexas/terraform-provider-polaris/internal/generated"
)

var pathParamPattern = regexp.MustCompile(`\{([^{}]+)\}`)

func operationByID(id string) (generated.Operation, error) {
	op, ok := generated.Operations[id]
	if !ok {
		suggestions := suggestOperationIDs(id)
		if len(suggestions) == 0 {
			return generated.Operation{}, fmt.Errorf("unknown Polaris OpenAPI operation_id %q", id)
		}
		return generated.Operation{}, fmt.Errorf("unknown Polaris OpenAPI operation_id %q (did you mean: %s)", id, strings.Join(suggestions, ", "))
	}
	return op, nil
}

func suggestOperationIDs(input string) []string {
	if input == "" || len(generated.Operations) == 0 {
		return nil
	}

	type scored struct {
		id   string
		cost int
	}
	params := levenshtein.NewParams()
	maxCost := 6
	switch {
	case len(input) <= 8:
		maxCost = 3
	case len(input) >= 32:
		maxCost = 8
	}
	candidates := make([]scored, 0, 3)
	for id := range generated.Operations {
		cost := levenshtein.Distance(input, id, params)
		if cost > maxCost {
			continue
		}
		candidates = append(candidates, scored{id: id, cost: cost})
	}
	if len(candidates) == 0 {
		return nil
	}
	sort.Slice(candidates, func(i, j int) bool {
		if candidates[i].cost != candidates[j].cost {
			return candidates[i].cost < candidates[j].cost
		}
		return candidates[i].id < candidates[j].id
	})

	max := 3
	if len(candidates) < max {
		max = len(candidates)
	}
	out := make([]string, 0, max)
	for _, c := range candidates[:max] {
		out = append(out, fmt.Sprintf("%q", c.id))
	}
	return out
}

func expandPath(pathTemplate string, params map[string]string) (string, error) {
	if pathTemplate == "" {
		return "", fmt.Errorf("path is required")
	}
	missing := []string{}
	expanded := pathParamPattern.ReplaceAllStringFunc(pathTemplate, func(match string) string {
		name := strings.Trim(match, "{}")
		value, ok := params[name]
		if !ok || value == "" {
			missing = append(missing, name)
			return match
		}
		return url.PathEscape(value)
	})
	if len(missing) > 0 {
		return "", fmt.Errorf("missing path_params: %s", strings.Join(missing, ", "))
	}
	if !strings.HasPrefix(expanded, "/") {
		expanded = "/" + expanded
	}
	return expanded, nil
}
