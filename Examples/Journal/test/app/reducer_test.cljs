(ns app.reducer-test
  (:require [cljs.test :refer [deftest testing is]]
            [app.main :as sut]))

(deftest app-reducer
  (testing "unknown action has no effect"
    (let [state-before {"entries" [{:entry/id 1} {:entry/id 2}]}
          state-after (sut/reducer state-before {:type "unknown"})]
      (is (= state-after state-before))))
  
  (testing "removing non-existing entry has no effect"
    (let [state-before {"entries" [{:entry/id 1} {:entry/id 2}]}
          state-after (sut/reducer state-before {:type "remove-entry" :payload {:entry/id 3}})]
      (is (= state-after state-before))))
  
  (testing "remove existing entry"
    (let [state-before {"entries" [{:entry/id 1} {:entry/id 2}]}
          state-after (sut/reducer state-before {:type "remove-entry" :payload {:entry/id 2}})]
      (is (= state-after {"entries" [{:entry/id 1}]})))))
