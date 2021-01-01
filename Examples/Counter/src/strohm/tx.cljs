(ns strohm.tx)

(defn- js->swift-handler []
  (.. js/window
      -webkit
      -messageHandlers
      -jsToSwift))

(defn- js->swift
  [msg]
  {:pre [(associative? msg)]}
  (.postMessage (js->swift-handler) msg))

(defn- android-webview? 
  []
  (.call (.-hasOwnProperty (.-prototype js/Object)) js/globalThis "strohmReceiveProps"))

(defn- ios-webview?
  []
  (some? (.-webkit js/window)))

(defn send-props
  [subscriptionId old-props new-props]
  (let [message {:function "subscriptionUpdate"
                 :subscriptionId (str subscriptionId)
                 :old old-props
                 :new new-props}]
    (cond
      (android-webview?)
      (.receiveProps (.-strohmReceiveProps js/globalThis)
                     (js/JSON.stringify (clj->js message)))

      (ios-webview?)
      (js->swift (clj->js message))

      :else
      (js/console.error "Neither Android nor iOS callback interface was found."))))
