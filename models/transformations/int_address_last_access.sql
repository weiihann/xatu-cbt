---
table: int_address_last_access
interval:
  max: 10000
schedules:
  forwardfill: "@every 1m"
  backfill: "@every 1m"
tags:
  - address
  - account
dependencies:
  - "{{external}}.canonical_execution_balance_diffs"
  - "{{external}}.canonical_execution_balance_reads"
  - "{{external}}.canonical_execution_contracts"
  - "{{external}}.canonical_execution_nonce_reads"
  - "{{external}}.canonical_execution_nonce_diffs"
  - "{{external}}.canonical_execution_storage_diffs"
  - "{{external}}.canonical_execution_storage_reads"
  - "{{external}}.canonical_execution_address_appearances"
---
INSERT INTO
  `{{ .self.database }}`.`{{ .self.table }}`
WITH latest_relationship AS (
  SELECT
    lower(address) AS address,
    argMax(relationship, (block_number, transaction_hash, internal_index)) AS relationship
  FROM `{{ index .dep "{{external}}" "canonical_execution_address_appearances" "database" }}`.`canonical_execution_address_appearances` FINAL
  WHERE block_number BETWEEN {{ .bounds.start }} AND {{ .bounds.end }}
  GROUP BY address
),
combined AS (
  SELECT
    FROM (
      SELECT lower(address) as address, block_number FROM `{{ index .dep "{{external}}" "canonical_execution_nonce_reads" "database" }}`.`canonical_execution_nonce_reads` FINAL
      WHERE block_number BETWEEN {{ .bounds.start }} AND {{ .bounds.end }}
      
      UNION ALL
      
      SELECT lower(address) as address, block_number FROM `{{ index .dep "{{external}}" "canonical_execution_nonce_diffs" "database" }}`.`canonical_execution_nonce_diffs` FINAL
      WHERE block_number BETWEEN {{ .bounds.start }} AND {{ .bounds.end }}
      
      UNION ALL
      
      SELECT lower(address) as address, block_number FROM `{{ index .dep "{{external}}" "canonical_execution_balance_diffs" "database" }}`.`canonical_execution_balance_diffs` FINAL
      WHERE block_number BETWEEN {{ .bounds.start }} AND {{ .bounds.end }}
      
      UNION ALL
      
      SELECT lower(address) as address, block_number FROM `{{ index .dep "{{external}}" "canonical_execution_balance_reads" "database" }}`.`canonical_execution_balance_reads` FINAL
      WHERE block_number BETWEEN {{ .bounds.start }} AND {{ .bounds.end }}
      
      UNION ALL
      
      SELECT lower(address) as address, block_number FROM `{{ index .dep "{{external}}" "canonical_execution_storage_diffs" "database" }}`.`canonical_execution_storage_diffs` FINAL
      WHERE block_number BETWEEN {{ .bounds.start }} AND {{ .bounds.end }}
      
      UNION ALL
      
      SELECT lower(contract_address) as address, block_number FROM `{{ index .dep "{{external}}" "canonical_execution_storage_reads" "database" }}`.`canonical_execution_storage_reads` FINAL
      WHERE block_number BETWEEN {{ .bounds.start }} AND {{ .bounds.end }}
      
      UNION ALL
      
      SELECT lower(contract_address) as address, block_number FROM `{{ index .dep "{{external}}" "canonical_execution_contracts" "database" }}`.`canonical_execution_contracts` FINAL
      WHERE block_number BETWEEN {{ .bounds.start }} AND {{ .bounds.end }}
  )
  GROUP BY address
)
SELECT 
    c.address,
    max(c.block_number) AS block_number,
    COALESCE(lr.relationship = 'suicide', false) AS is_deleted
FROM combined c
GLOBAL LEFT JOIN latest_relationship lr
  ON c.address = lr.address
