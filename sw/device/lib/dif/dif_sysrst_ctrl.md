---
title: "System Reset Controller DIF Checklist"
---

This checklist is for [Development Stage]({{< relref "/doc/project/development_stages.md" >}}) transitions for the [System Reset Controller DIF]({{< relref "hw/ip/sysrst_ctrl/doc" >}}).
All checklist items refer to the content in the [Checklist]({{< relref "/doc/project/checklist.md" >}}).

<h2>DIF Checklist</h2>

<h3>S1</h3>

Type           | Item                 | Resolution  | Note/Collaterals
---------------|----------------------|-------------|------------------
Implementation | [DIF_EXISTS][]       | In Progress |
Implementation | [DIF_USED_IN_TREE][] | In Progress |
Tests          | [DIF_TEST_SMOKE][]   | Not Started |

[DIF_EXISTS]:       {{< relref "/doc/project/checklist.md#dif_exists" >}}
[DIF_USED_IN_TREE]: {{< relref "/doc/project/checklist.md#dif_used_in_tree" >}}
[DIF_TEST_SMOKE]:   {{< relref "/doc/project/checklist.md#dif_test_smoke" >}}

<h3>S2</h3>

Type           | Item                        | Resolution  | Note/Collaterals
---------------|-----------------------------|-------------|------------------
Coordination   | [DIF_HW_FEATURE_COMPLETE][] | Done        | [HW Dashboard]({{< relref "hw" >}})
Implementation | [DIF_FEATURES][]            | In Progress |
Coordination   | [DIF_DV_TESTS][]            | Not Started |

[DIF_HW_FEATURE_COMPLETE]: {{< relref "/doc/project/checklist.md#dif_hw_feature_complete" >}}
[DIF_FEATURES]:            {{< relref "/doc/project/checklist.md#dif_features" >}}
[DIF_DV_TESTS]:            {{< relref "/doc/project/checklist.md#dif_dv_tests" >}}

<h3>S3</h3>

Type           | Item                             | Resolution  | Note/Collaterals
---------------|----------------------------------|-------------|------------------
Coordination   | [DIF_HW_DESIGN_COMPLETE][]       | Not Started |
Coordination   | [DIF_HW_VERIFICATION_COMPLETE][] | Not Started |
Documentation  | [DIF_DOC_HW][]                   | Not Started |
Code Quality   | [DIF_CODE_STYLE][]               | Not Started |
Tests          | [DIF_TEST_UNIT][]                | In Progress |
Review         | [DIF_TODO_COMPLETE][]            | Not Started |
Review         | Reviewer(s)                      | Not Started |
Review         | Signoff date                     | Not Started |

[DIF_HW_DESIGN_COMPLETE]:       {{< relref "/doc/project/checklist.md#dif_hw_design_complete" >}}
[DIF_HW_VERIFICATION_COMPLETE]: {{< relref "/doc/project/checklist.md#dif_hw_verification_complete" >}}
[DIF_DOC_HW]:                   {{< relref "/doc/project/checklist.md#dif_doc_hw" >}}
[DIF_CODE_STYLE]:               {{< relref "/doc/project/checklist.md#dif_code_style" >}}
[DIF_TEST_UNIT]:                {{< relref "/doc/project/checklist.md#dif_test_unit" >}}
[DIF_TODO_COMPLETE]:            {{< relref "/doc/project/checklist.md#dif_todo_complete" >}}
