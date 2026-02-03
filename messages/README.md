# Language Files for Statusline

This directory contains translations for the statusline context usage messages.

## Structure

Each language file (e.g., `en.json`, `pt.json`, `es.json`) is a JSON file with the following structure:

```json
{
  "language": "en",
  "display_name": "English",
  "tiers": {
    "very_low": ["message1", "message2", ...],
    "low": ["message1", "message2", ...],
    "medium": ["message1", "message2", ...],
    "high": ["message1", "message2", ...],
    "critical": ["message1", "message2", ...]
  }
}
```

- `very_low`: 0-20% context usage (~22 messages)
- `low`: 21-40% context usage (~22 messages)
- `medium`: 41-60% context usage (~23 messages)
- `high`: 61-80% context usage (~24 messages)
- `critical`: 81-100% context usage (~28 messages)

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
   - Update `"language"` to language code (e.g., "de")
   - Update `"display_name"` to language name (e.g., "Deutsch")
   - Translate all messages in each tier array
   - Maintain similar tone/style for each tier
   - Adapt cultural references

3. **Validate JSON**:
   ```bash
   jq empty messages/de.json
   ```

4. **Update installers**:

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

5. **Run tests**:
   ```bash
   ./tests/unit.sh
   ./tests/integration.sh
   ```

6. **Submit PR** with new language file and installer updates

## Testing Your Translation

```bash
# Validate JSON syntax
jq empty messages/your-lang.json

# Test message loading
echo '{"model":{"display_name":"Test"},"workspace":{"current_dir":"/tmp"},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":5000}},"cost":{"total_cost_usd":0}}' | \
  MESSAGES_DIR=./messages \
  CONFIG_FILE=<(echo "{\"language\":\"your-lang\",\"show_messages\":true,\"show_cost\":true}") \
  ./statusline.sh
```

## Cultural Adaptation Examples

### Brazilian Portuguese
- "this is fine" → "tá tranquilo, tá favorável" (popular BR meme)
- "yolo mode engaged" → "o que vier é lucro" (BR expression)
- "houston we have a problem" → "deu ruim" (BR slang)

### Spanish
- "hold my drink" → "sostén mi bebida" (direct translation)
- "yolo mode activated" → "modo yolo activado" (YOLO is universal)

## File Format

```bash
#!/usr/bin/env bash
# [Language Name] messages for statusline
# DO NOT execute directly - sourced by statusline.sh

# Tier 0: Very low usage (0-20%)
readonly CONTEXT_MSG_VERY_LOW=(
  "message 1"
  "message 2"
  # ...
)

# Tier 1: Low usage (21-40%)
readonly CONTEXT_MSG_LOW=(
  "message 1"
  "message 2"
  # ...
)

# Tier 2: Medium usage (41-60%)
readonly CONTEXT_MSG_MEDIUM=(
  "message 1"
  "message 2"
  # ...
)

# Tier 3: High usage (61-80%)
readonly CONTEXT_MSG_HIGH=(
  "message 1"
  "message 2"
  # ...
)

# Tier 4: Critical usage (81-100%)
readonly CONTEXT_MSG_CRITICAL=(
  "message 1"
  "message 2"
  # ...
)
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
