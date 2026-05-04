#import "@preview/diatypst:0.9.1": *
#import "@preview/cetz:0.4.0"
#import "@preview/cetz-venn:0.1.4": venn2
#import "@preview/fletcher:0.5.8": diagram, edge, node

#show: slides.with(
  title: "Language Server Protocol",
  subtitle: "Editors, language tools, and JSON-RPC",
  authors: "Bc. Ondřej Hložek",
  layout: "medium",
  ratio: 16 / 9,
  title-color: rgb("17345c"),
  bg-color: rgb("fbfbff"),
  count: "number",
  toc: false,
  theme: "normal",
)

#let blue = rgb("3468c0")
#let note(body) = text(size: 0.82em, fill: rgb("5d667a"))[#body]
#let client-color = rgb("9fc5ff").transparentize(35%)
#let server-color = rgb("9de0d8").transparentize(35%)
#let node-stroke = 0.9pt + rgb("17345c")
#let client-fill = rgb("eaf1ff")
#let server-fill = rgb("e8f8fa")
#let neutral-fill = rgb("f0f2f7")

#let capability-venn() = align(center)[
  #cetz.canvas(length: 1.65cm, {
    import cetz.draw: *

    venn2(
      name: "cap",
      a-fill: client-color,
      b-fill: server-color,
      ab-fill: rgb("d7f1d2"),
      stroke: 1pt + rgb("17345c"),
    )
    content("cap.a", [#text(size: 1.2em, weight: "bold")[B]])
    content("cap.b", [#text(size: 1.2em, weight: "bold")[A]])
    content("cap.ab", [#text(size: 1.2em, weight: "bold")[C]])
  })
]

= Why LSP Exists

== Microsoft and VS Code

- Language Server Protocol was created by Microsoft to solve a practical problem:
  editor fragmentation and duplicated tooling effort.
- When building VS Code, Microsoft wanted fast support for many languages.
- They did not want to maintain custom language logic for every language inside the editor.

#v(0.55cm)

#align(center)[
  #grid(columns: (auto, auto), gutter: 1.4cm,
    align(center)[
      #image("assets/microsoft.svg", width: 1.35cm)
      #v(0.15cm)
      #text(weight: "bold")[Microsoft]
    ],
    align(center)[
      #image("assets/vscode.svg", width: 1.35cm)
      #v(0.15cm)
      #text(weight: "bold")[VS Code]
    ],
  )
]

== The Problem Before LSP

Every combination needed custom integration:

#align(center)[
  #diagram(
    node-stroke: node-stroke,
    node-fill: neutral-fill,
    spacing: 2.4em,
    node((0, 0), [VS Code], corner-radius: 4pt),
    node((0, 1), [Vim], corner-radius: 4pt),
    node((0, 2), [Sublime], corner-radius: 4pt),
    node((1, 0), [JavaScript], corner-radius: 4pt),
    node((1, 1), [Python], corner-radius: 4pt),
    node((1, 2), [Rust], corner-radius: 4pt),
    edge((0, 0), (1, 0), "-|>"),
    edge((0, 0), (1, 1), "-|>"),
    edge((0, 0), (1, 2), "-|>"),
    edge((0, 1), (1, 0), "-|>"),
    edge((0, 1), (1, 1), "-|>"),
    edge((0, 1), (1, 2), "-|>"),
    edge((0, 2), (1, 0), "-|>"),
    edge((0, 2), (1, 1), "-|>"),
    edge((0, 2), (1, 2), "-|>"),
  )
]

- Language authors wrote multiple plugins.
- Editor teams implemented support for many languages.
- Autocomplete, go-to-definition, and refactoring were inconsistent.

== The N Times M Problem

Before LSP:

```txt
N languages × M editors = N*M integrations

Example:
10 languages × 5 editors = 50 integrations
```

After LSP:

```txt
N languages + M editors = N + M integrations

Example:
10 language servers + 5 editor clients = 15 integrations
```

#note[The important change is the standard boundary between editor and language tooling.]

== Two Different Processes

#align(center)[
  #diagram(
    node-stroke: node-stroke,
    spacing: 3.2em,
    node((0, 0), align(center)[*PID 4210*\ VS Code\ buffers + UI + keybindings], fill: client-fill, corner-radius: 4pt),
    edge("d", "<|-|>", [stdio / pipe / socket]),
    node(
      (0, 1),
      align(center)[*PID 4248*\ rust-analyzer\ parser + index + type checker],
      fill: server-fill,
      corner-radius: 4pt,
    ),
  )
]

#note[This is why LSP also has distributed-systems concerns: async messages, latency, cancellation, and failures.]

= Protocol Basics

== JSON-RPC

- LSP messages are JSON-RPC 2.0 payloads.
- Transport is usually stdio, pipes, or sockets.
- The base protocol adds headers, especially `Content-Length`.

From the LSP specification:

```json
Content-Length: ...\r\n
\r\n
{
	"jsonrpc": "2.0",
	"id": 1,
	"method": "textDocument/completion",
	"params": {
		...
	}
}
```

== Notification Example

Requests have an `id`; notifications do not.

```json
{
  "jsonrpc": "2.0",
  "method": "textDocument/didChange",
  "params": {
    "textDocument": {
      "uri": "file:///project/main.rs",
      "version": 12
    },
    "contentChanges": [
      { "text": "fn main() { println!(\"hi\"); }" }
    ]
  }
}
```

#note[`didChange` is fire-and-forget: the server updates its document state but sends no direct response.]

== Message Shapes

```ts
interface RequestMessage extends Message {
  id: integer | string;
  method: string;
  params?: array | object;
}

interface NotificationMessage extends Message {
  method: string;
  params?: array | object;
}
```

```txt
Request       -> expects Response
Notification  -> no response, event-style
Response      -> result or error for a request id
```

== Client and Server

#align(center)[
  #diagram(
    node-stroke: node-stroke,
    node-fill: neutral-fill,
    spacing: 3.2em,
    node((0, 0), [User action], corner-radius: 4pt),
    edge("d", "-|>"),
    node((0, 1), [Editor / LSP client], fill: client-fill, corner-radius: 4pt),
    edge("d", "-|>", [JSON-RPC]),
    node((0, 2), [Language server process], fill: server-fill, corner-radius: 4pt),
    edge("d", "-|>", [structured result]),
    node((0, 3), [Editor renders UI], fill: client-fill, corner-radius: 4pt),
  )
]

#note[The server returns data. The editor decides how to display completion menus, hovers, squiggles, and edits.]

= Lifecycle

== Startup Handshake

#v(0.55cm)

#align(center)[
  #diagram(
    node-stroke: node-stroke,
    node-fill: neutral-fill,
    spacing: (20em, 2.25em),
    node((0, 0), [Client], fill: client-fill, corner-radius: 4pt),
    node((1, 0), [Server], fill: server-fill, corner-radius: 4pt),
    node((0, 1), [], width: 0.1em, height: 0.1em, stroke: none, fill: none),
    node((1, 1), [], width: 0.1em, height: 0.1em, stroke: none, fill: none),
    node((0, 2), [], width: 0.1em, height: 0.1em, stroke: none, fill: none),
    node((1, 2), [], width: 0.1em, height: 0.1em, stroke: none, fill: none),
    node((0, 3), [], width: 0.1em, height: 0.1em, stroke: none, fill: none),
    node((1, 3), [], width: 0.1em, height: 0.1em, stroke: none, fill: none),
    edge((0, 0), (0, 3), stroke: 0.6pt + rgb("8a93a6")),
    edge((1, 0), (1, 3), stroke: 0.6pt + rgb("8a93a6")),
    edge((0, 1), (1, 1), "-|>", [`initialize`: client capabilities, workspace, process]),
    edge((1, 2), (0, 2), "-|>", [`initialize result`: server capabilities]),
    edge((0, 3), (1, 3), "-|>", [`initialized`]),
  )
]

- Both sides announce supported features.
- Clients should ignore unknown server capabilities.
- Servers only use features the client understands.

== Capabilities as a Venn Diagram

#capability-venn()

- A = server capabilities
- B = client capabilities
- C = shared usable features

#note[Example: a server may support semantic tokens, but it should only send them if the client announced support.]

== Document Synchronization

```txt
textDocument/didOpen
  full text enters server memory

textDocument/didChange
  either full document
  or incremental changed ranges

textDocument/didSave
  optional save notification

textDocument/didClose
  server can release document state
```

#note[The server often works from the editor buffer, not only from files on disk.]

= Language Features

== Common Requests

Requests:

```txt
textDocument/completion       suggestions at cursor
textDocument/hover            docs and type information
textDocument/definition       jump to symbol definition
textDocument/references       find symbol usages
textDocument/formatting       return text edits
textDocument/codeAction       quick fixes and refactors
```

Server -> Client notifications:

```txt
textDocument/publishDiagnostics
window/showMessage
$/progress
```

== Completion Flow

#align(center)[
  #diagram(
    node-stroke: node-stroke,
    node-fill: neutral-fill,
    spacing: 2.5em,
    node((0, 0), [User types\ `pri|`], corner-radius: 4pt),
    edge("d", "-|>"),
    node((0, 1), [Client sends\ `textDocument/completion`], fill: client-fill, corner-radius: 4pt),
    edge("d", "-|>"),
    node((0, 2), [Server returns\ `print`, `printf`, `private`], fill: server-fill, corner-radius: 4pt),
    edge("d", "-|>"),
    node((0, 3), [Editor renders menu], fill: client-fill, corner-radius: 4pt),
  )
]

== Diagnostics Flow

#align(center)[
  #diagram(
    node-stroke: node-stroke,
    node-fill: neutral-fill,
    spacing: 3.0em,
    node((0, 0), [User edits file], corner-radius: 4pt),
    edge("d", "-|>", [`didChange`]),
    node((0, 1), [Server re-analyzes], fill: server-fill, corner-radius: 4pt),
    edge("d", "-|>", [parse + type + lint]),
    node((0, 2), [`publishDiagnostics`], fill: server-fill, corner-radius: 4pt),
    edge("d", "-|>"),
    node((0, 3), [Editor draws squiggles\ and problems list], fill: client-fill, corner-radius: 4pt),
  )
]

== Trade-Offs

```txt
Strengths
  + one server reaches many editors
  + editors avoid language-specific logic
  + language teams reuse compiler knowledge

Challenges
  - latency matters
  - cancellation must be handled carefully
  - protocol cannot express every custom UI idea
  - indexing large repositories is expensive
```

== Takeaways

```txt
1. LSP was created by Microsoft around VS Code.

2. It standardizes editor <-> language tool communication.

3. It is based on JSON-RPC 2.0 messages.

4. The server provides structured language intelligence.

5. The editor owns the user interface.
```

#align(center)[#text(size: 1.55em, weight: "bold", fill: blue)[Questions?]]
