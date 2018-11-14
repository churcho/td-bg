# Changelog

## [2.7.7] 2018-11-12

### Changed

- Update TD-DF-LIB to validate dependant fields

## [2.7.6] 2018-11-08

### Removed

- Remove migration that drops the deprecated Templates table

## [2.7.5] 2018-11-07

### Changed

- Template fields with no type are now interpreted as type "string"

## [2.7.4] 2018-11-07

### Changed

- Use TdPerms.MockDynamicFormCache instead of TdBg.MockDfCache for DfCache testing

## [2.7.3] 2018-11-06

### Added

- Delete /api/templates endpoint
- /api/domains/#id/templates endpoint now reads from Redis Cache written by Td-Df

## [2.7.1] 2018-10-29

### Added

- Deleting unused endpoints on search controller
- Modify endpoint from /api/search/reindex_all to /api/business_concepts/search/reindex_all
- Verify if the user is admin while calling reindex_all