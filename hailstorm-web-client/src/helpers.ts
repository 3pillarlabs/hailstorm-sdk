// Helper functions (this will be broken with clarity on the nature of the functions)

// ellipsis(string) if length is greater than max-length
/**
 * @returns {[string, boolean]} boolean is true if the string was truncated
 */
export function ellipsis({ longText, maxLength = 16 }: { longText: string; maxLength?: number; }): [string, boolean] {
  return longText.length < maxLength ? [longText, false] : [`${longText.slice(0, maxLength).trimEnd()}...`, true];
}

// "this world" -> "This World"
export function titleCase(value: string): string {
  return value.split(/\s/).map((word) => `${word[0].toUpperCase()}${word.slice(1)}`).join(" ");
}
