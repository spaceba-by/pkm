(ns workflows.engine-test
  "Tests for workflow template interpolation, context building and output paths"
  (:require [clojure.test :refer [deftest is testing]]
            [clojure.string :as str]
            [workflow.engine :as engine])
  (:import [java.time Instant]))

;; =============================================================================
;; template-variables / validate-template
;; =============================================================================

(deftest template-variables-test
  (testing "Extracts distinct variables in order"
    (is (= ["document.title" "document.content" "entity.names"]
           (engine/template-variables
            "Title: {{document.title}}\n{{ document.content }}\n{{document.title}} {{entity.names}}"))))

  (testing "Tolerates whitespace inside braces"
    (is (= ["now.date"] (engine/template-variables "{{   now.date   }}"))))

  (testing "Blank or nil template has no variables"
    (is (= [] (engine/template-variables nil)))
    (is (= [] (engine/template-variables "")))
    (is (= [] (engine/template-variables "plain text")))))

(deftest validate-template-test
  (testing "Valid template produces no errors"
    (is (= [] (engine/validate-template "Summarize {{document.body}} for {{workflow.name}}"))))

  (testing "Unknown root is reported once"
    (let [errors (engine/validate-template "{{foo.bar}} {{foo.baz}} {{document.title}}")]
      (is (= 1 (count errors)))
      (is (str/includes? (first errors) "foo"))))

  (testing "Unbalanced braces are reported"
    (is (seq (engine/validate-template "Hello {{document.title")))
    (is (seq (engine/validate-template "Hello document.title}}"))))

  (testing "Invalid expression syntax is reported"
    (is (seq (engine/validate-template "{{document title}}")))
    (is (seq (engine/validate-template "{{document..title}}"))))

  (testing "Nil template is valid"
    (is (= [] (engine/validate-template nil)))))

;; =============================================================================
;; render-value / lookup / render
;; =============================================================================

(deftest render-value-test
  (is (= "" (engine/render-value nil)))
  (is (= "hello" (engine/render-value "hello")))
  (is (= "42" (engine/render-value 42)))
  (is (= "a, b, c" (engine/render-value ["a" "b" "c"])))
  (is (= "a, b" (engine/render-value #{"b" "a"})))
  (is (= "{\"k\":\"v\"}" (engine/render-value {:k "v"})))
  (is (= "1, 2" (engine/render-value [1 2]))))

(deftest lookup-test
  (let [ctx {:document {:title "T" :frontmatter {"status" "draft" :owner "me"}}}]
    (testing "Resolves keyword keys"
      (is (= "T" (engine/lookup ctx "document.title"))))
    (testing "Resolves string keys from parsed YAML"
      (is (= "draft" (engine/lookup ctx "document.frontmatter.status")))
      (is (= "me" (engine/lookup ctx "document.frontmatter.owner"))))
    (testing "Missing segments return nil"
      (is (nil? (engine/lookup ctx "document.missing")))
      (is (nil? (engine/lookup ctx "nothing.here")))
      (is (nil? (engine/lookup ctx "document.title.deeper"))))))

(deftest render-test
  (let [ctx {:document {:title "Standup" :tags ["work" "team"]}
             :entity {:names ["Alice" "Acme"]}
             :now {:date "2026-11-15"}}]
    (testing "Substitutes variables"
      (is (= "Standup on 2026-11-15: work, team"
             (engine/render "{{document.title}} on {{now.date}}: {{document.tags}}" ctx))))

    (testing "Unresolved variables render empty"
      (is (= "A  B" (engine/render "A {{document.missing}} B" ctx))))

    (testing "Text without variables is unchanged"
      (is (= "no vars" (engine/render "no vars" ctx))))

    (testing "Nil template renders empty"
      (is (= "" (engine/render nil ctx))))

    (testing "Replacement text with $ and backslash is literal"
      (let [ctx {:document {:title "Cost $5 \\ more"}}]
        (is (= "Cost $5 \\ more" (engine/render "{{document.title}}" ctx)))))))

;; =============================================================================
;; Context building
;; =============================================================================

(deftest document-context-test
  (testing "Builds from metadata and content with frontmatter"
    (let [content "---\ntitle: Weekly Sync\nstatus: draft\n---\n\n# Weekly Sync\n\nNotes here."
          ctx (engine/document-context "meetings/weekly.md"
                                       {:title "Weekly Sync" :tags ["meeting"]
                                        :classification "meeting"
                                        :created "2026-11-01T00:00:00Z"
                                        :modified "2026-11-02T00:00:00Z"}
                                       content)]
      (is (= "meetings/weekly.md" (:path ctx)))
      (is (= "Weekly Sync" (:title ctx)))
      (is (= content (:content ctx)))
      (is (= "# Weekly Sync\n\nNotes here." (:body ctx)))
      (is (= ["meeting"] (:tags ctx)))
      (is (= "meeting" (:classification ctx)))
      (is (= "2026-11-01T00:00:00Z" (:created ctx)))
      (is (= "draft" (get-in ctx [:frontmatter :status])))))

  (testing "Falls back to filename title and empty collections without metadata"
    (let [ctx (engine/document-context "ideas/Big Idea.md" nil "Just text")]
      (is (= "Big Idea" (:title ctx)))
      (is (= [] (:tags ctx)))
      (is (nil? (:classification ctx)))
      (is (= {} (:frontmatter ctx)))
      (is (= "Just text" (:body ctx)))))

  (testing "Truncates long content"
    (let [long-content (apply str (repeat (+ engine/max-document-chars 100) "x"))
          ctx (engine/document-context "a/b.md" nil long-content)]
      (is (< (count (:content ctx)) (count long-content)))
      (is (str/ends-with? (:content ctx) "[... truncated ...]")))))

(deftest entity-context-test
  (testing "Builds lists and the union of names"
    (let [ctx (engine/entity-context {:people ["Alice"] :organizations ["Acme"]
                                      :concepts ["OKRs"] :locations []})]
      (is (= ["Alice"] (:people ctx)))
      (is (= ["Acme"] (:organizations ctx)))
      (is (= ["Alice" "Acme" "OKRs"] (:names ctx)))))

  (testing "Handles nil entities"
    (let [ctx (engine/entity-context nil)]
      (is (= [] (:people ctx)))
      (is (= [] (:names ctx)))))

  (testing "Handles string keys"
    (is (= ["Bob"] (:people (engine/entity-context {"people" ["Bob"]}))))))

(deftest documents-context-test
  (testing "Builds count, list and content"
    (let [ctx (engine/documents-context [{:title "A" :path "x/a.md" :body "body a"}
                                         {:title "B" :path "x/b.md" :body "body b"}])]
      (is (= 2 (:count ctx)))
      (is (= "- A (x/a.md)\n- B (x/b.md)" (:list ctx)))
      (is (str/includes? (:content ctx) "## A\n\nbody a"))
      (is (str/includes? (:content ctx) "## B\n\nbody b"))))

  (testing "Empty set"
    (let [ctx (engine/documents-context [])]
      (is (= 0 (:count ctx)))
      (is (= "" (:list ctx)))
      (is (= "" (:content ctx))))))

(deftest command-context-test
  (is (= {:name "research" :args "quantum computing" :text "@workflow:research quantum computing"}
         (engine/command-context {:name "research" :args "quantum computing"})))
  (is (= {:name "research" :args "" :text "@workflow:research"}
         (engine/command-context {:name "research" :args nil}))))

(deftest now-context-test
  (let [ctx (engine/now-context (Instant/parse "2026-11-16T09:30:15.123Z"))]
    (is (= "2026-11-16T09:30:15Z" (:iso ctx)))
    (is (= "2026-11-16" (:date ctx)))
    (is (= "monday" (:weekday ctx)))))

(deftest build-context-test
  (testing "Single document trigger"
    (let [ctx (engine/build-context
               {:workflow {:workflow_id "wf-1" :name "action-items"}
                :run-id "run-1"
                :document {:path "meetings/a.md"
                           :metadata {:title "A" :entities {:people ["Alice"]}}
                           :content "# A\n\n- [ ] do thing"}
                :now (Instant/parse "2026-11-15T12:00:00Z")})]
      (is (= "wf-1" (get-in ctx [:workflow :id])))
      (is (= "action-items" (get-in ctx [:workflow :name])))
      (is (= "run-1" (get-in ctx [:run :id])))
      (is (= "A" (get-in ctx [:document :title])))
      (is (= ["Alice"] (get-in ctx [:entity :people])))
      (is (= "2026-11-15" (get-in ctx [:now :date])))
      (is (not (contains? ctx :documents)))
      (is (not (contains? ctx :command)))))

  (testing "Document set trigger with command"
    (let [ctx (engine/build-context
               {:workflow {:workflow_id "wf-2" :name "weekly"}
                :run-id "run-2"
                :documents [{:title "A" :path "a.md" :body "x"}]
                :command {:name "weekly" :args "brief"}})]
      (is (= 1 (get-in ctx [:documents :count])))
      (is (= "brief" (get-in ctx [:command :args])))
      (is (not (contains? ctx :document)))
      (is (string? (get-in ctx [:now :iso])))))

  (testing "Renders a realistic prompt end to end"
    (let [ctx (engine/build-context
               {:workflow {:workflow_id "wf-1" :name "action-items"}
                :run-id "run-1"
                :document {:path "meetings/a.md"
                           :metadata {:title "Planning" :tags ["meeting" "q4"]}
                           :content "---\ntitle: Planning\n---\nAgenda"}})]
      (is (= "Extract action items from Planning (meeting, q4):\nAgenda"
             (engine/render "Extract action items from {{document.title}} ({{document.tags}}):\n{{document.body}}"
                            ctx))))))

;; =============================================================================
;; Output paths
;; =============================================================================

(deftest normalize-output-path-test
  (testing "Accepts a normal path"
    (is (= "_agent/workflows/notes/2026-11-15-run.md"
           (engine/normalize-output-path "_agent/workflows/notes/2026-11-15-run.md"))))

  (testing "Appends .md when missing"
    (is (= "_agent/actions/Planning.md" (engine/normalize-output-path "_agent/actions/Planning"))))

  (testing "Strips leading slash, dot segments and repeated slashes"
    (is (= "_agent/a/b.md" (engine/normalize-output-path "/_agent//./a/b.md"))))

  (testing "Rejects any .. segment, even one that would stay under _agent/"
    (is (thrown? clojure.lang.ExceptionInfo
                 (engine/normalize-output-path "_agent/a/../a/b.md")))
    (is (thrown? clojure.lang.ExceptionInfo
                 (engine/normalize-output-path "_agent/../notes/b.md"))))

  (testing "Sanitizes unsafe characters but keeps spaces"
    (is (= "_agent/actions/Weekly Sync - Q4-.md"
           (engine/normalize-output-path "_agent/actions/Weekly Sync : Q4?.md"))))

  (testing "Rejects paths outside _agent/"
    (is (thrown? clojure.lang.ExceptionInfo (engine/normalize-output-path "notes/a.md")))
    (is (thrown? clojure.lang.ExceptionInfo (engine/normalize-output-path "_agentx/a.md")))
    (is (thrown? clojure.lang.ExceptionInfo (engine/normalize-output-path "")))
    (is (thrown? clojure.lang.ExceptionInfo (engine/normalize-output-path nil))))

  (testing "Rejects _agent/ with no file beneath it"
    (is (thrown? clojure.lang.ExceptionInfo (engine/normalize-output-path "_agent/")))
    (is (thrown? clojure.lang.ExceptionInfo (engine/normalize-output-path "_agent"))))

  (testing "Validation error carries :type :validation"
    (try
      (engine/normalize-output-path "notes/a.md")
      (is false "expected exception")
      (catch clojure.lang.ExceptionInfo e
        (is (= :validation (:type (ex-data e)))))))

  (testing "Default template renders to an allowed path"
    (let [ctx (engine/build-context {:workflow {:workflow_id "wf" :name "digest"}
                                     :run-id "abc"
                                     :now (Instant/parse "2026-11-15T12:00:00Z")})]
      (is (= "_agent/workflows/digest/2026-11-15-abc.md"
             (engine/normalize-output-path (engine/render engine/default-output-path ctx)))))))

(deftest output-path-template-allowed-test
  (is (engine/output-path-template-allowed? "_agent/actions/{{document.title}}.md"))
  (is (engine/output-path-template-allowed? "  _agent/x.md"))
  (is (not (engine/output-path-template-allowed? "{{document.path}}")))
  (is (not (engine/output-path-template-allowed? "notes/_agent/x.md")))
  (is (not (engine/output-path-template-allowed? nil))))

(deftest render-output-document-test
  (testing "Includes frontmatter header and result"
    (let [doc (engine/render-output-document
               {:workflow-name "action-items" :run-id "run-1" :trigger "document"
                :document-path "meetings/a \"quoted\".md" :model-id "model-x"
                :generated-at "2026-11-15T12:00:00Z"}
               "- [ ] Follow up")]
      (is (str/starts-with? doc "---\nworkflow: \"action-items\"\n"))
      (is (str/includes? doc "run_id: run-1\n"))
      (is (str/includes? doc "trigger: document\n"))
      (is (str/includes? doc "source_document: \"meetings/a \\\"quoted\\\".md\"\n"))
      (is (str/includes? doc "model: model-x\n"))
      (is (str/includes? doc "generated_at: 2026-11-15T12:00:00Z\n"))
      (is (str/ends-with? doc "---\n\n- [ ] Follow up\n"))))

  (testing "Omits source_document when absent"
    (let [doc (engine/render-output-document
               {:workflow-name "w" :run-id "r" :trigger "schedule"
                :model-id "m" :generated-at "t"}
               nil)]
      (is (not (str/includes? doc "source_document")))
      (is (str/ends-with? doc "---\n\n\n")))))
