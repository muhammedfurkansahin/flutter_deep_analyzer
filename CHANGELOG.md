# Changelog

## 0.1.0

- Initial release
- 7 analyzer modules: Architecture, Code Quality, Best Practice, Security, Race Condition, Performance, Memory Leak
- 47 analysis rules
- Scoring system (0-100 with A-F grades)
- Console, JSON, and HTML report formats
- CLI with category filtering and configurable thresholds
- YAML-based configuration via `analysis_options.yaml`

## 1.0.0

- Initial release
- 7 analyzer modules: Architecture, Code Quality, Best Practice, Security, Race Condition, Performance, Memory Leak
- 47 analysis rules
- Scoring system (0-100 with A-F grades)
- Console, JSON, and HTML report formats
- CLI with category filtering and configurable thresholds
- YAML-based configuration via `analysis_options.yaml`

## 1.0.1

- Fix analyzer version

## 1.0.2

- Support backward compatibility for analyzer package (<10.0.0 and <=6.4.1) by handling getter access correctly (e.g. `node.name.lexeme` versus tokens/identifiers).
