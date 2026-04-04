import os
import re
import tiktoken


def count_tokens(text: str) -> int:
    if not tiktoken:
        return 0
    # cl100k_base is standard for most modern LLMs
    encoding = tiktoken.get_encoding("cl100k_base")
    return len(encoding.encode(text))


def clean_markdown_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    input_tokens = count_tokens(content)

    # 1. Remove the phantom <!-- image --> tags (and trailing newlines)
    content = re.sub(r'<!-- image -->\n*', '', content)

    # 2. Force § and Art. into strict Markdown Headers.
    # Catches the like "- § 1.", "§ 1.", or "12. § 1." at the line start
    content = re.sub(r'^(?:-\s+|\d+\.\s+)?(§\s*\d+[a-z]*\.)', r'### \1', content, flags=re.MULTILINE)
    content = re.sub(r'^(?:-\s+|\d+\.\s+)?(Art\.\s*\d+[a-z]*\.)', r'### \1', content, flags=re.MULTILINE)

    # 3. Clean up numbered lists that Docling messed up (e.g. "12. '1) text'")
    # Converts "12. '1) text'" to just "1) text"
    content = re.sub(r'^\d+\.\s+((?:\'|")?\d+\))', r'\1', content, flags=re.MULTILINE)

    # 4. Clean up rogue bullets/stray hyphens on standard numbered items
    # Converts "- 1) text" to "1) text"
    content = re.sub(r'^-\s+(\d+\))', r'\1', content, flags=re.MULTILINE)

    # 5. Clean up rogue bullets/stray hyphens on standard legal numbering
    # Converts "- 1. text" to "1. text"
    content = re.sub(r'^-\s+(\d+\.\s+)', r'\1', content, flags=re.MULTILINE)

    # 6. Normalize blank lines (reduce 3+ blank lines to exactly 2)
    content = re.sub(r'\n{3,}', '\n\n', content)

    # 7. Remove rogue quotes at the start of legal list items ("'1)" to "1)")
    content = re.sub(r'^[\'"](\d+\))', r'\1', content, flags=re.MULTILINE)

    output_tokens = count_tokens(content)

    # Write the cleaned content back to the file
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

    return input_tokens, output_tokens


def main():
    folder_path = input("Enter the folder path containing .md files: ").strip()

    if not os.path.isdir(folder_path):
        print(f"Error: The folder '{folder_path}' does not exist.")
        return

    # Find all markdown files in the given directory
    md_files = [f for f in os.listdir(folder_path) if f.endswith('.md')]

    if not md_files:
        print(f"No .md files found in '{folder_path}'.")
        return

    print(f"Found {len(md_files)} .md files. Starting cleaning...")

    success_count = 0
    total_input_tokens = 0
    total_output_tokens = 0

    for filename in md_files:
        file_path = os.path.join(folder_path, filename)
        try:
            in_tok, out_tok = clean_markdown_file(file_path)
            total_input_tokens += in_tok
            total_output_tokens += out_tok
            success_count += 1
        except Exception as e:
            print(f"Error processing {filename}: {e}")

    print(f"✅ Successfully cleaned {success_count} files!")

    if tiktoken:
        print(f" Input tokens: {total_input_tokens:,}")
        print(f" Output tokens: {total_output_tokens:,}")
        print(f" Tokens saved: {total_input_tokens - total_output_tokens:,}")


if __name__ == "__main__":
    main()
