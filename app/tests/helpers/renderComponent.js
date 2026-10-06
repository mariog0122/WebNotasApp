import { createRenderer, h, ssrContextKey } from 'vue'

// Mount component setup in a real Vue lifecycle. Vitest compiles SFCs for SSR;
// DOM rendering is covered by Playwright, so this host tests their async state.
const node = (type, text = '') => ({ type, text, props: {}, children: [], parent: null })
const renderer = createRenderer({
  createElement: type => node(type),
  createText: text => node('#text', text),
  createComment: text => node('#comment', text),
  setText: (el, text) => { el.text = text },
  setElementText: (el, text) => { el.text = text; el.children = [] },
  patchProp: (el, key, _previous, value) => { el.props[key] = value },
  insert(el, parent, anchor = null) {
    if (el.parent) el.parent.children.splice(el.parent.children.indexOf(el), 1)
    const index = anchor ? parent.children.indexOf(anchor) : -1
    parent.children.splice(index < 0 ? parent.children.length : index, 0, el)
    el.parent = parent
  },
  remove(el) { if (el.parent) el.parent.children.splice(el.parent.children.indexOf(el), 1) },
  parentNode: el => el.parent,
  nextSibling: el => el.parent?.children[el.parent.children.indexOf(el) + 1] || null,
})

export function renderComponent(component, props) {
  const root = node('root')
  const app = renderer.createApp({ render: () => h({ ...component, render: () => null }, props) })
  app.provide(ssrContextKey, {})
  const instance = app.mount(root)
  return { state: instance.$.subTree.component.setupState, unmount: () => app.unmount() }
}
