# Language Files for Statusline

This directory contains translations for the statusline context usage messages.

## Structure

Each language file (e.g., `en.json`, `pt.json`, `es.json`) is a JSON file with a **simplified structure**:

```json
{
  "very_low": ["message1", "message2", ...],
  "low": ["message1", "message2", ...],
  "medium": ["message1", "message2", ...],
  "high": ["message1", "message2", ...],
  "critical": ["message1", "message2", ...]
}
```

**Tier meanings**:
- `very_low`: 0-20% context usage (~22 messages)
- `low`: 21-40% context usage (~22 messages)
- `medium`: 41-60% context usage (~23 messages)
- `high`: 61-80% context usage (~24 messages)
- `critical`: 81-100% context usage (~28 messages)

**Note**: Metadata fields (`language`, `display_name`) and `tiers` nesting have been removed for simplicity.

## Translation Guidelines

### Tone Progression

Messages should follow a thematic escalation:

- **VERY_LOW**: Relaxed, peaceful, just starting
- **LOW**: Comfortable, cruising, easy going
- **MEDIUM**: Engaged, balanced, finding rhythm
- **HIGH**: Heating up, intense, getting serious
- **CRITICAL**: Emergency, extreme, danger zone

### Message Style

- **Length**: 2-5 words (compact for terminal display)
- **Tone**: Playful, self-aware humor
- **Cultural adaptation**: Adapt memes and references to target culture
- **Array size**: ±3 messages per tier is acceptable

### Examples

**English (original)**:
- VERY_LOW: "just getting started"
- LOW: "cruising altitude reached"
- MEDIUM: "halfway there"
- HIGH: "entering danger zone"
- CRITICAL: "this is fine"

**Portuguese (cultural adaptation)**:
- VERY_LOW: "começando agora"
- LOW: "altitude de cruzeiro"
- MEDIUM: "na metade do caminho"
- HIGH: "entrando na zona de perigo"
- CRITICAL: "tá tranquilo, tá favorável"

**Spanish (translation)**:
- VERY_LOW: "apenas comenzando"
- LOW: "altitud de crucero alcanzada"
- MEDIUM: "a mitad de camino"
- HIGH: "entrando en zona de peligro"
- CRITICAL: "esto está bien"

## Adding a New Language

1. **Copy template**:
   ```bash
   cp messages/en.json messages/de.json
   ```

2. **Edit the JSON file**:
   - Translate all messages in each tier array
   - Maintain similar tone/style for each tier
   - Adapt cultural references
   - Keep the simplified structure (no metadata fields)

3. **Validate JSON**:
   ```bash
   jq empty messages/de.json
   ```

4. **Test patching**:
   ```bash
   ./patch-statusline.sh statusline.sh messages/de.json
   ```

5. **Update installers** (optional, if using install.sh):

   **install.sh** (around line 480):
   ```bash
   local available_languages=("en" "pt" "es" "de")
   ```

   **install.ps1** (around line 308):
   ```powershell
   $languages = @(
       @{ Code = "en"; Name = "English" },
       @{ Code = "pt"; Name = "Português" },
       @{ Code = "es"; Name = "Español" },
       @{ Code = "de"; Name = "Deutsch" }
   )
   ```

6. **Run tests**:
   ```bash
   ./tests/unit.sh
   ./tests/integration.sh
   ```

7. **Submit PR** with new language file and installer updates

## Testing Your Translation

```bash
# Validate JSON syntax
jq empty messages/your-lang.json

# Patch statusline with your language
cp statusline.sh statusline-test.sh
./patch-statusline.sh statusline-test.sh messages/your-lang.json

# Test with sample input
echo '{"model":{"display_name":"Test"},"workspace":{"current_dir":"/tmp"},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":5000}},"cost":{"total_cost_usd":0}}' | ./statusline-test.sh

# Cleanup
rm statusline-test.sh
```

## Cultural Adaptation Examples

### Brazilian Portuguese
- "this is fine" → "tá tranquilo, tá favorável" (popular BR meme)
- "yolo mode engaged" → "o que vier é lucro" (BR expression)
- "houston we have a problem" → "deu ruim" (BR slang)

### Spanish
- "hold my drink" → "sostén mi bebida" (direct translation)
- "yolo mode activated" → "modo yolo activado" (YOLO is universal)

## How Patching Works

The `patch-statusline.sh` script:
1. Reads your JSON language file
2. Converts JSON arrays to bash arrays using `jq @sh` (proper escaping)
3. Replaces the `@MESSAGES_START` / `@MESSAGES_END` block in statusline.sh
4. Creates a fully static script with your language hardcoded

Example transformation:
```json
{
  "very_low": ["just getting started", "barely touched it"]
}
```

Becomes:
```bash
readonly CONTEXT_MSG_VERY_LOW=('just getting started' 'barely touched it')
```

## Language Codes

Use ISO 639-1 two-letter codes:
- `en` - English
- `pt` - Portuguese
- `es` - Spanish
- `fr` - French
- `de` - German
- `it` - Italian
- `ja` - Japanese
- `zh` - Chinese
- etc.

## Contributing

1. Fork the repository
2. Create language file following guidelines above
3. Test thoroughly
4. Submit pull request with:
   - New language file in `messages/`
   - Updated `install.sh` with language option
   - Brief description of cultural adaptations made

## Questions?

Open an issue on GitHub if you need help with translations or have questions about cultural adaptation.
