-- Black Mountain / Bennett political contributions — verification query
-- Source: Texas Ethics Commission bulk export, loaded to Postgres db `tec_finance`
-- (schema tec_finance, table contributions_raw, 35.9M rows).
-- Data currency: contributions through 2026-06-30, from reports received through
-- the 2026-07-15 semiannual filing deadline. Anything given after 2026-06-30 is
-- not yet reportable and will not appear here.
--
-- Name note: the CEO appears under two name forms — "Rhett Bennett" and
-- "John Bennett" — both at Fort Worth addresses with Black Mountain employers and
-- Founder/CEO or Chairman occupations. A 2018-04-23 filing under the full name
-- "John Rhett Miles Bennett" (Black Mountain Oil & Gas, CEO, Fort Worth 76102)
-- ties the two forms to one person. Totals below combine them, as the TEC record
-- supports; each row remains individually citable by report id.

SELECT filer_name, filer_ident, report_info_ident AS report_id, received_dt,
       coalesce(contributor_name_organization,
                contributor_name_first || ' ' || contributor_name_last) AS donor,
       contributor_employer, contributor_occupation,
       contribution_dt, contribution_amount
FROM tec_finance.contributions_raw
WHERE (upper(coalesce(contributor_name_organization,'')) LIKE '%BLACK MOUNTAIN%'
    OR (upper(coalesce(contributor_name_last,'')) = 'BENNETT'
        AND upper(coalesce(contributor_employer,'')) LIKE '%BLACK MOUNTAIN%'))
  AND contribution_dt >= '20240101'
ORDER BY contribution_dt;
