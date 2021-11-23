# Architecture

How this architecture differs from MVC and how's the dataflow?

## Overview

This dataflow is, somehow, an implementation of MVC, one that differs significantly from the Apple's MVC for offering a very strict and opinionated description of layers' responsibilities and by enforcing the growth of the Model layer, through a better definition of how it should be implemented: in this scenario, the Model is the Store. All your Controller has to do is to forward view actions to the Store and subscribe to state changes, updating the views whenever needed. If this flow doesn't sound like MVC, let's check a picture taken from Apple's website:

![iOS MVC](CocoaMVC)

One important distinction is about the user action: on SwiftRex it's forwarded by the controller and reaches the Store, so the responsibility of updating the state becomes the Store's responsibility now. The rest is pretty much the same, but with a better definition of how the Model operates.

```
     ╼━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╾
    ╱░░░░░░░░░░░░░░░░░◉░░░░░░░░░░░░░░░░░░╲
  ╱░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░╲
 ┃░░░░░░░░░░░░░◉░░◖■■■■■■■◗░░░░░░░░░░░░░░░░░┃
 ┃░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░┃
╭┃░╭━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╮░┃
│┃░┃             ┌──────────┐             ┃░┃
╰┃░┃             │ UIButton │────────┐    ┃░┃
 ┃░┃             └──────────┘        │    ┃░┃
╭┃░┃         ┌───────────────────┐   │    ┃░┃╮ dispatch<Action>(_ action: Action)
│┃░┃         │UIGestureRecognizer│───┼──────────────────────────────────────────────┐
│┃░┃         └───────────────────┘   │    ┃░┃│                                      │
╰┃░┃             ┌───────────┐       │    ┃░┃│                                      ▼
╭┃░┃             │viewDidLoad│───────┘    ┃░┃╯                           ┏━━━━━━━━━━━━━━━━━━━━┓
│┃░┃             └───────────┘            ┃░┃                            ┃                    ┃░
│┃░┃                                      ┃░┃                            ┃                    ┃░
╰┃░┃                                      ┃░┃                            ┃                    ┃░
 ┃░┃               ┌───────┐              ┃░┃                            ┃                    ┃░
 ┃░┃               │UILabel│◀─ ─ ─ ─ ┐    ┃░┃                            ┃                    ┃░
 ┃░┃               └───────┘              ┃░┃  Combine, RxSwift    ┌ ─ ─ ┻ ─ ┐                ┃░
 ┃░┃                                 │    ┃░┃  or ReactiveSwift       State      Store        ┃░
 ┃░┃        ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ╋░─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─│Publisher│                ┃░
 ┃░┃        ▼               │             ┃░┃  subscribe(onNext:)                             ┃░
 ┃░┃ ┌─────────────┐        ▼             ┃░┃  sink(receiveValue:) └ ─ ─ ┳ ─ ┘                ┃░
 ┃░┃ │  Diffable   │ ┌─────────────┐      ┃░┃  assign(to:on:)            ┃                    ┃░
 ┃░┃ │ DataSource  │ │RxDataSources│      ┃░┃                            ┃                    ┃░
 ┃░┃ └─────────────┘ └─────────────┘      ┃░┃                            ┃                    ┃░
 ┃░┃        │               │             ┃░┃                            ┃                    ┃░
 ┃░┃ ┌──────▼───────────────▼───────────┐ ┃░┃                            ┗━━━━━━━━━━━━━━━━━━━━┛░
 ┃░┃ │                                  │ ┃░┃                             ░░░░░░░░░░░░░░░░░░░░░░
 ┃░┃ │                                  │ ┃░┃
 ┃░┃ │                                  │ ┃░┃
 ┃░┃ │                                  │ ┃░┃
 ┃░┃ │         UICollectionView         │ ┃░┃
 ┃░┃ │                                  │ ┃░┃
 ┃░┃ │                                  │ ┃░┃
 ┃░┃ │                                  │ ┃░┃
 ┃░┃ │                                  │ ┃░┃
 ┃░┃ └──────────────────────────────────┘ ┃░┃
 ┃░╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╯░┃
 ┃░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░┃
 ┃░░░░░░░░░░░░░░░░░░░▓▓▓▓░░░░░░░░░░░░░░░░░░░┃
 ┃░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░┃
  ╲░░░░░░░░░░░░░░░░░░▓▓▓▓░░░░░░░░░░░░░░░░░░╱
    ╲░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░╱
     ╼━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╾
```

You can think of Store as a very heavy "Model" layer, completely detached from the View and Controller, and where all the business logic stands. At a first sight it may look like transferring the "Massive" problem from a layer to another, so that's why the Store is nothing but a collection of composable boxes with very well defined roles and, most importantly, restrictions.

```
     ╼━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╾
    ╱░░░░░░░░░░░░░░░░░◉░░░░░░░░░░░░░░░░░░╲
  ╱░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░╲
 ┃░░░░░░░░░░░░░◉░░◖■■■■■■■◗░░░░░░░░░░░░░░░░░┃
 ┃░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░┃
╭┃░╭━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╮░┃
│┃░┃               ┌────────┐             ┃░┃
╰┃░┃               │ Button │────────┐    ┃░┃
 ┃░┃               └────────┘        │    ┃░┃              ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐             ┏━━━━━━━━━━━━━━━━━━━━━━━┓
╭┃░┃          ┌──────────────────┐   │    ┃░┃╮ dispatch                                            ┃                       ┃░
│┃░┃          │      Toggle      │───┼────────────────────▶│   ─ ─ ─ ─ ─ ─ ─ ─ ─ ─▶  │────────────▶┃                       ┃░
│┃░┃          └──────────────────┘   │    ┃░┃│ view event      f: (Event) → Action     app action  ┃                       ┃░
╰┃░┃              ┌──────────┐       │    ┃░┃│             │                         │             ┃                       ┃░
╭┃░┃              │ onAppear │───────┘    ┃░┃╯                                                     ┃                       ┃░
│┃░┃              └──────────┘            ┃░┃              │   ObservableViewModel   │             ┃                       ┃░
│┃░┃                                      ┃░┃                                                      ┃                       ┃░
╰┃░┃                                      ┃░┃              │     a projection of     │  projection ┃         Store         ┃░
 ┃░┃                                      ┃░┃                   the actual store                   ┃                       ┃░
 ┃░┃                                      ┃░┃              │                         │             ┃                       ┃░
 ┃░┃      ┌────────────────────────┐      ┃░┃                                                      ┃                       ┃░
 ┃░┃      │                        │      ┃░┃              │                         │            ┌┃─ ─ ─ ─ ─ ┐            ┃░
 ┃░┃      │    @ObservedObject     │◀ ─ ─ ╋░─ ─ ─ ─ ─ ─ ─ ─    ◀─ ─ ─ ─ ─ ─ ─ ─ ─ ─   ◀─ ─ ─ ─ ─ ─    State                ┃░
 ┃░┃      │                        │      ┃░┃  view state  │   f: (State) → View     │  app state │ Publisher │            ┃░
 ┃░┃      └────────────────────────┘      ┃░┃                               State                  ┳ ─ ─ ─ ─ ─             ┃░
 ┃░┃        │          │          │       ┃░┃              └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘             ┗━━━━━━━━━━━━━━━━━━━━━━━┛░
 ┃░┃        ▼          ▼          ▼       ┃░┃                                                       ░░░░░░░░░░░░░░░░░░░░░░░░░
 ┃░┃   ┌────────┐ ┌────────┐ ┌────────┐   ┃░┃
 ┃░┃   │  Text  │ │  List  │ │ForEach │   ┃░┃
 ┃░┃   └────────┘ └────────┘ └────────┘   ┃░┃
 ┃░┃                                      ┃░┃
 ┃░┃                                      ┃░┃
 ┃░┃                                      ┃░┃
 ┃░┃                                      ┃░┃
 ┃░┃                                      ┃░┃
 ┃░┃                                      ┃░┃
 ┃░┃                                      ┃░┃
 ┃░┃                                      ┃░┃
 ┃░┃                                      ┃░┃
 ┃░┃                                      ┃░┃
 ┃░╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╯░┃
 ┃░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░┃
 ┃░░░░░░░░░░░░░░░░░░░▓▓▓▓░░░░░░░░░░░░░░░░░░░┃
 ┃░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░┃
  ╲░░░░░░░░░░░░░░░░░░▓▓▓▓░░░░░░░░░░░░░░░░░░╱
    ╲░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░╱
     ╼━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╾
```

And what about SwiftUI? Is this architecture a good fit for the new UI framework? In fact, this architecture works even better in SwiftUI, because SwiftUI was inspired by several functional patterns and it's reactive and stateless by conception. It was said multiple times during WWDC 2019 that, in SwiftUI, the **View is a function of the state**, and that we should always aim for single source of truth and the data should always flow in a single direction.

![SwiftUI Unidirectional Flow](wwdc2019-226-01)
