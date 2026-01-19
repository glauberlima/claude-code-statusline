# Language Files for Statusline

This directory contains translations for the statusline context usage messages.

## Structure

Each language file (e.g., `en.sh`, `pt.sh`, `es.sh`) defines 5 readonly bash arrays:

- `CONTEXT_MSG_VERY_LOW`: 0-20% context usage (~22 messages)
- `CONTEXT_MSG_LOW`: 21-40% context usage (~22 messages)
- `CONTEXT_MSG_MEDIUM`: 41-60% context usage (~23 messages)
- `CONTEXT_MSG_HIGH`: 61-80% context usage (~24 messages)
- `CONTEXT_MSG_CRITICAL`: 81-100% context usage (~28 messages)

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
   cp messages/en.sh messages/de.sh
   ```

2. **Translate messages**:
   - Keep array names identical
   - Translate strings only
   - Maintain similar tone/style for each tier
   - Adapt cultural references

3. **Test syntax**:
   ```bash
   bash -n messages/de.sh
   shellcheck messages/de.sh
   ```

4. **Update install.sh** (around line 330):
   ```bash
   local available_languages=("en" "pt" "es" "de")
   local lang_names=("English" "Português" "Español" "Deutsch")
   ```

5. **Run tests**:
   ```bash
   ./tests/unit.sh
   ./tests/integration.sh
   ```

6. **Submit PR** with new language file and install.sh update

## Testing Your Translation

```bash
# Test syntax
bash -n messages/your-lang.sh

# Test with shellcheck
shellcheck messages/your-lang.sh

# Test integration
STATUSLINE_LANGUAGE="your-lang" ./tests/integration.sh
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
