(ns strohm.debug
  (:require [clojure.string :as str]))

(def ^:private log-enabled? (atom false))

(defn set-logging-enabled!
  [enabled]
  (reset! log-enabled? enabled))

(defn log [& args]
  (when @log-enabled?
    (if-let [document (.-document js/window)]
      (let [contentDiv (.getElementById document "content")
            oldHtml    (.-innerHTML contentDiv)]
        (set! (.-innerHTML contentDiv)
              (str oldHtml "<br/>\n[js] " (str/join " " args))))
      (apply js/console.debug args))))

(defn clear-log []
  (when @log-enabled?
    (let [contentDiv (.getElementById js/document "content")]
      (set! (.-innerHTML contentDiv) ""))))

(comment 
  (clear-log))