(ns api.graph-data-test
  "Tests for knowledge graph data API.

   Note: The build-graph function is duplicated here as a contract test
   (same pattern as handlers_test.clj) because all handlers share the
   'handler' namespace name, preventing direct imports."
  (:require [clojure.test :refer [deftest is testing]]
            [clojure.string :as str]))

(def entity-types #{"people" "organizations" "concepts" "locations"})

(defn- entity-node-id [entity-type entity-name]
  (str "entity:" entity-type ":" (str/lower-case entity-name)))

(defn- tag-node-id [tag-name]
  (str "tag:" (str/lower-case tag-name)))

(defn- doc-node-id [doc-path]
  (str "doc:" doc-path))

(defn- extract-title-from-path [path]
  (-> path
      (str/split #"/")
      last
      (str/replace #"\.md$" "")
      (str/replace #"[-_]" " ")))

(defn build-graph
  "Build graph nodes and edges from document metadata (from api_graph_data)"
  [documents]
  (let [nodes (atom {})
        edges (atom [])
        edge-set (atom #{})

        add-node! (fn [id node-data]
                    (swap! nodes assoc id node-data))

        add-edge! (fn [source target edge-type weight]
                    (let [edge-key (if (neg? (compare source target))
                                     [source target edge-type]
                                     [target source edge-type])]
                      (when-not (contains? @edge-set edge-key)
                        (swap! edge-set conj edge-key)
                        (swap! edges conj {:source source
                                           :target target
                                           :type edge-type
                                           :weight (or weight 1)}))))]

    (doseq [doc documents]
      (let [doc-path (:PK doc)
            doc-id (doc-node-id doc-path)
            title (or (:title doc) (extract-title-from-path doc-path))
            classification (or (:classification doc) "reference")
            entities (or (:entities doc) {})
            tags (or (:tags doc) [])
            links-to (or (:links_to doc) [])]

        (add-node! doc-id {:id doc-id
                           :type "document"
                           :label title
                           :path doc-path
                           :classification classification})

        (doseq [entity-type entity-types]
          (let [type-key (keyword entity-type)
                entity-names (get entities type-key [])]
            (doseq [entity-name entity-names
                    :when (and entity-name (not (str/blank? entity-name)))]
              (let [eid (entity-node-id entity-type entity-name)]
                (add-node! eid {:id eid
                                :type "entity"
                                :label entity-name
                                :entityType entity-type})
                (add-edge! doc-id eid "mentions" 1)))))

        (doseq [tag tags
                :when (and tag (not (str/blank? tag)))]
          (let [tid (tag-node-id tag)]
            (add-node! tid {:id tid
                            :type "tag"
                            :label tag})
            (add-edge! doc-id tid "tagged" 1)))

        (doseq [link links-to
                :when (and link (not (str/blank? link)))]
          (let [link-path (if (str/ends-with? link ".md") link (str link ".md"))
                link-id (doc-node-id link-path)]
            (add-edge! doc-id link-id "links_to" 2)))))

    (doseq [doc documents]
      (let [entities (or (:entities doc) {})
            all-entity-ids (for [entity-type entity-types
                                 entity-name (get entities (keyword entity-type) [])
                                 :when (and entity-name (not (str/blank? entity-name)))]
                             (entity-node-id entity-type entity-name))]
        (doseq [[i a] (map-indexed vector all-entity-ids)
                b (drop (inc i) all-entity-ids)]
          (add-edge! a b "co_occurrence" 1))))

    {:nodes (vec (vals @nodes))
     :edges @edges}))

;; =============================================================================
;; Node ID tests
;; =============================================================================

(deftest node-id-test
  (testing "Entity node IDs are normalized to lowercase"
    (is (= "entity:people:alice" (entity-node-id "people" "Alice")))
    (is (= "entity:organizations:acme corp" (entity-node-id "organizations" "Acme Corp"))))

  (testing "Tag node IDs are normalized to lowercase"
    (is (= "tag:meeting" (tag-node-id "meeting")))
    (is (= "tag:swift" (tag-node-id "Swift"))))

  (testing "Document node IDs use full path"
    (is (= "doc:notes/test.md" (doc-node-id "notes/test.md")))))

(deftest extract-title-from-path-test
  (testing "Extracts title from path"
    (is (= "test" (extract-title-from-path "notes/test.md")))
    (is (= "meeting notes" (extract-title-from-path "notes/meeting-notes.md")))
    (is (= "my project" (extract-title-from-path "projects/my_project.md")))))

;; =============================================================================
;; Build graph tests
;; =============================================================================

(deftest build-graph-empty-test
  (testing "Empty documents produce empty graph"
    (let [graph (build-graph [])]
      (is (= [] (:nodes graph)))
      (is (= [] (:edges graph))))))

(deftest build-graph-single-document-test
  (testing "Single document produces document node"
    (let [docs [{:PK "notes/test.md"
                 :title "Test Doc"
                 :classification "reference"}]
          graph (build-graph docs)
          nodes (:nodes graph)]
      (is (= 1 (count nodes)))
      (is (= "doc:notes/test.md" (:id (first nodes))))
      (is (= "document" (:type (first nodes))))
      (is (= "Test Doc" (:label (first nodes))))
      (is (= "reference" (:classification (first nodes)))))))

(deftest build-graph-document-with-entities-test
  (testing "Document with entities creates entity nodes and mention edges"
    (let [docs [{:PK "notes/meeting.md"
                 :title "Meeting Notes"
                 :classification "meeting"
                 :entities {:people ["Alice" "Bob"]
                            :organizations ["Acme"]}}]
          graph (build-graph docs)
          nodes (:nodes graph)
          edges (:edges graph)
          node-ids (set (map :id nodes))
          mention-edges (filter #(= "mentions" (:type %)) edges)]
      ;; 1 document + 2 people + 1 org = 4 nodes
      (is (= 4 (count nodes)))
      (is (contains? node-ids "doc:notes/meeting.md"))
      (is (contains? node-ids "entity:people:alice"))
      (is (contains? node-ids "entity:people:bob"))
      (is (contains? node-ids "entity:organizations:acme"))
      ;; 3 mention edges
      (is (= 3 (count mention-edges))))))

(deftest build-graph-document-with-tags-test
  (testing "Document with tags creates tag nodes and tagged edges"
    (let [docs [{:PK "notes/test.md"
                 :title "Test"
                 :tags ["swift" "ios"]}]
          graph (build-graph docs)
          nodes (:nodes graph)
          edges (:edges graph)
          node-ids (set (map :id nodes))
          tag-edges (filter #(= "tagged" (:type %)) edges)]
      ;; 1 document + 2 tags = 3 nodes
      (is (= 3 (count nodes)))
      (is (contains? node-ids "tag:swift"))
      (is (contains? node-ids "tag:ios"))
      (is (= 2 (count tag-edges))))))

(deftest build-graph-document-with-links-test
  (testing "Document with wikilinks creates links_to edges"
    (let [docs [{:PK "notes/project.md"
                 :title "Project"
                 :links_to ["notes/meeting.md" "reference"]}]
          graph (build-graph docs)
          edges (:edges graph)
          link-edges (filter #(= "links_to" (:type %)) edges)]
      ;; 2 link edges (one to existing path, one with .md appended)
      (is (= 2 (count link-edges)))
      ;; links_to edges have weight 2
      (is (every? #(= 2 (:weight %)) link-edges)))))

(deftest build-graph-co-occurrence-test
  (testing "Entities in same document get co-occurrence edges"
    (let [docs [{:PK "notes/test.md"
                 :title "Test"
                 :entities {:people ["Alice" "Bob"]
                            :concepts ["PKM"]}}]
          graph (build-graph docs)
          co-edges (filter #(= "co_occurrence" (:type %)) (:edges graph))]
      ;; Alice-Bob, Alice-PKM, Bob-PKM = 3 co-occurrence edges
      (is (= 3 (count co-edges))))))

(deftest build-graph-deduplication-test
  (testing "Same entity mentioned in multiple documents creates one node"
    (let [docs [{:PK "notes/a.md" :title "A" :entities {:people ["Alice"]}}
                {:PK "notes/b.md" :title "B" :entities {:people ["Alice"]}}]
          graph (build-graph docs)
          alice-nodes (filter #(= "entity:people:alice" (:id %)) (:nodes graph))]
      (is (= 1 (count alice-nodes)))))

  (testing "Same tag in multiple documents creates one node"
    (let [docs [{:PK "notes/a.md" :title "A" :tags ["swift"]}
                {:PK "notes/b.md" :title "B" :tags ["swift"]}]
          graph (build-graph docs)
          swift-nodes (filter #(= "tag:swift" (:id %)) (:nodes graph))]
      (is (= 1 (count swift-nodes))))))

(deftest build-graph-edge-deduplication-test
  (testing "Duplicate edges are not created"
    (let [docs [{:PK "notes/a.md" :title "A" :tags ["swift"]}]
          graph (build-graph docs)
          tagged-edges (filter #(= "tagged" (:type %)) (:edges graph))]
      (is (= 1 (count tagged-edges))))))

(deftest build-graph-missing-fields-test
  (testing "Documents with missing fields produce valid graph"
    (let [docs [{:PK "notes/minimal.md"}]
          graph (build-graph docs)
          nodes (:nodes graph)]
      (is (= 1 (count nodes)))
      (is (= "minimal" (:label (first nodes))))
      (is (= "reference" (:classification (first nodes))))
      (is (= [] (:edges graph))))))

(deftest build-graph-blank-entities-test
  (testing "Blank entity names are skipped"
    (let [docs [{:PK "notes/test.md"
                 :title "Test"
                 :entities {:people ["Alice" "" nil]}
                 :tags ["valid" "" nil]}]
          graph (build-graph docs)
          entity-nodes (filter #(= "entity" (:type %)) (:nodes graph))
          tag-nodes (filter #(= "tag" (:type %)) (:nodes graph))]
      (is (= 1 (count entity-nodes)))
      (is (= 1 (count tag-nodes))))))

(deftest build-graph-multiple-documents-test
  (testing "Multiple documents with shared entities create connected graph"
    (let [docs [{:PK "notes/a.md"
                 :title "Doc A"
                 :entities {:people ["Alice"]}
                 :tags ["project"]}
                {:PK "notes/b.md"
                 :title "Doc B"
                 :entities {:people ["Alice" "Bob"]}
                 :tags ["project" "meeting"]}]
          graph (build-graph docs)
          nodes (:nodes graph)
          edges (:edges graph)]
      ;; 2 docs + 2 people (alice, bob) + 2 tags (project, meeting) = 6 nodes
      (is (= 6 (count nodes)))
      ;; Edges:
      ;; doc-a -> alice (mention), doc-a -> project (tagged)
      ;; doc-b -> alice (mention), doc-b -> bob (mention), doc-b -> project (tagged), doc-b -> meeting (tagged)
      ;; alice-bob co-occurrence (from doc-b)
      (let [mention-edges (filter #(= "mentions" (:type %)) edges)
            tagged-edges (filter #(= "tagged" (:type %)) edges)
            co-edges (filter #(= "co_occurrence" (:type %)) edges)]
        (is (= 3 (count mention-edges)))
        (is (= 3 (count tagged-edges)))
        (is (= 1 (count co-edges)))))))
