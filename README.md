# Language Server Protocol Presentation

Concise Typst slide deck about the Language Server Protocol (LSP).

## Contents

- `lsp.typ` - source slides
- `assets/` - SVG logos used in the deck

## Build

Requires Typst with package access.

```sh
typst compile lsp.typ
```

The deck uses:

- `diatypst` for slides
- `fletcher` for diagrams
- `cetz-venn` for the capabilities Venn diagram

## Topic

The presentation covers LSP motivation, JSON-RPC basics, lifecycle, synchronization, common servers and adoption.
