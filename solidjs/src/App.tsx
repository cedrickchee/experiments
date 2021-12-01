import {
  createSignal, 
  Suspense, 
  Switch, 
  Match,
} from "solid-js";
import type { Component } from "solid-js";
import Child from "./child"

import "./styles.css";

const App: Component = () => {
  const [tab, setTab] = createSignal(0);
  const updateTab = (index: number) => () => setTab(index);

  return (
    <>
      <div class="title">Async/Transitions and Suspense Example</div>
      <ul class="inline">
        <li classList={{ selected: tab() === 0 }} onClick={updateTab(0)}>
          Uno
        </li>
        <li classList={{ selected: tab() === 1 }} onClick={updateTab(1)}>
          Dos
        </li>
        <li classList={{ selected: tab() === 2 }} onClick={updateTab(2)}>
          Tres
        </li>
      </ul>
      <div class="tab">
        <Suspense fallback={<div class="loader">Loading...</div>}>
          <Switch>
            <Match when={tab() === 0}>
              <Child page="Uno" />
            </Match>
            <Match when={tab() === 1}>
              <Child page="Dos" />
            </Match>
            <Match when={tab() === 2}>
              <Child page="Tres" />
            </Match>
          </Switch>
        </Suspense>
      </div>
    </>
  );
};

export default App;
