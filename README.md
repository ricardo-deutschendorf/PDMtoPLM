> [!WARNING]
> ## Work in Progress
>
> **PDMtoPLM is currently under development and is not ready for production use.**
>
> Some steps still require validation, error handling improvements, and testing in the Siemens Teamcenter 2312 environment. Use this tool only in controlled test environments until the migration workflow is fully validated.

## Summary

This PR introduces an automated PDM-to-PLM migration workflow for **Siemens Teamcenter 2312**, enabling the conversion and import of engineering CAD data with minimal user interaction.

The solution retrieves source CAD files from the PDM environment, processes the models through **SolidWorks**, executes the required conversion using **Siemens NX**, and imports the resulting engineering data into Teamcenter.

The workflow creates the corresponding Teamcenter objects and attaches the generated datasets to the appropriate Item Revision. The main objective is to simplify engineering data migration, reduce manual operations, and improve the reliability and traceability of the import process.

**Current status:** Work in progress  
**Related Issue:** Closes #XX

---

## Changes

- Added automated CAD file retrieval from the PDM environment.
- Added support for SolidWorks source files.
- Implemented an automated workflow for Siemens Teamcenter 2312.
- Integrated SolidWorks model processing.
- Added automated Siemens NX Batch execution.
- Automated the ImportSW2NX form interaction and conversion process.
- Added Teamcenter Item and Item Revision creation.
- Implemented automatic Dataset creation and attachment.
- Added duplicate Item ID handling for test executions.
- Added execution logs for validation and troubleshooting.
- Improved error reporting during conversion and import operations.
- Reduced the number of manual steps required during CAD migration.

---

## Workflow

The PDM-to-PLM migration follows this process:

1. The user provides the source Item ID.
2. The system locates the associated CAD files in the PDM environment.
3. The SolidWorks source model is prepared for processing.
4. Siemens NX is started in Batch mode.
5. The SolidWorks model is opened within the NX import session.
6. The ImportSW2NX form is automatically populated.
7. The conversion is confirmed and executed without additional user interaction.
8. The converted NX files and required datasets are generated.
9. Teamcenter 2312 creates the corresponding Item and Item Revision.
10. The generated datasets are attached to the created Item Revision.
11. The imported engineering structure becomes available in Teamcenter.

This workflow combines PDM file retrieval, SolidWorks processing, NX conversion, and Teamcenter import into a single automated process.

---

## How to Test

1. Run the PDM-to-PLM import tool.
2. Enter a valid source Item ID.
3. Select the required SolidWorks CAD model.
4. Verify that the conversion workflow starts automatically.
5. Confirm that Siemens NX starts in Batch mode.
6. Verify that the ImportSW2NX form is populated automatically.
7. Wait for the conversion and import processes to finish.
8. Verify in Teamcenter 2312 that:
   - The Item was created successfully.
   - The Item Revision was created.
   - The NX Dataset was generated.
   - The converted CAD files were attached correctly.
   - The model can be opened through Teamcenter and NX.

> [!IMPORTANT]
> Testing should currently be performed only in the Teamcenter test environment. Do not use production data until all remaining checklist items have been validated.

---

## Technical Notes

- Designed for Siemens Teamcenter 2312 environments.
- Uses SolidWorks as the source CAD platform.
- Uses Siemens NX and ImportSW2NX for CAD conversion.
- Supports unattended conversion through NX Batch.
- Automates the ImportSW2NX user interface interaction.
- Creates and relates Teamcenter objects and datasets.
- Provides execution logs for validation and troubleshooting.
- Requires access to the PDM source files and the target Teamcenter environment.

---

## Checklist

- [x] PDM source file retrieval implemented
- [x] SolidWorks source file processing implemented
- [x] Siemens NX Batch execution implemented
- [x] ImportSW2NX form automation implemented
- [x] Automatic conversion confirmation implemented
- [x] Teamcenter connection implemented
- [x] Teamcenter Item creation implemented
- [x] Teamcenter Item Revision creation implemented
- [x] Dataset creation implemented
- [x] Dataset attachment implemented
- [x] Duplicate Item ID handling implemented
- [x] Execution logs implemented
- [x] Basic error reporting implemented
- [x] Tested locally
- [x] Used with Siemens Teamcenter 2312
- [ ] Complete workflow validated in the Teamcenter test environment
- [ ] Converted model structure fully validated
- [ ] Dataset relationships fully validated
- [ ] Additional error scenarios tested
- [ ] Production environment validation completed
- [ ] Documentation finalized
- [ ] Ready for production use

---

## Known Limitations

- The project is still under development.
- Some error scenarios may not yet be handled automatically.
- The workflow depends on the availability and configuration of SolidWorks, Siemens NX, ImportSW2NX, and Teamcenter 2312.
- Environment-specific paths and settings may require manual configuration.
- The complete migration workflow still requires validation before production use.
- Unexpected SolidWorks model structures or missing references may interrupt the conversion process.

---

## Additional Notes

PDMtoPLM is intended to automate the migration of engineering CAD data into Siemens Teamcenter 2312.

By integrating PDM file retrieval, SolidWorks processing, Siemens NX conversion, ImportSW2NX automation, and Teamcenter object creation into a single workflow, the solution aims to reduce processing time, minimize repetitive manual operations, and improve traceability throughout the CAD migration process.

The project is not finalized and should remain restricted to controlled development and testing environments until all conversion, dataset, relationship, and production-readiness checks have been completed.
