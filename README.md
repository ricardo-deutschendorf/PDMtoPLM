## Summary

This PR introduces an automated PDM-to-PLM migration workflow for **Siemens Teamcenter 2312**, enabling the conversion and import of engineering CAD data with minimal user interaction.

The solution retrieves source CAD files from the PDM environment, executes the required conversion process through **SolidWorks** and **NX**, creates the corresponding Teamcenter objects, and attaches the generated datasets to the appropriate item revision. The objective is to simplify the migration process, improve reliability, and reduce manual effort during engineering data onboarding.

**Related Issue:** Closes #XX

---

## Changes

- Added automated CAD file retrieval from the PDM environment.
- Implemented end-to-end migration workflow for Siemens Teamcenter 2312.
- Integrated SolidWorks-based source model processing.
- Added automated NX conversion execution through NX Batch.
- Implemented automatic ImportSW2NX workflow execution.
- Added Teamcenter Item and Revision creation.
- Implemented automatic Dataset creation and attachment.
- Improved duplicate item handling and validation.
- Added detailed execution logging for troubleshooting and auditability.
- Enhanced error reporting throughout the migration process.
- Reduced manual intervention required during CAD imports.

---

## Workflow

The migration process follows the workflow below:

1. User provides the source item information.
2. The system locates the CAD files in the PDM environment.
3. The source model is opened and processed through SolidWorks.
4. NX Batch is launched automatically.
5. ImportSW2NX executes the CAD conversion workflow.
6. NX datasets are generated.
7. Teamcenter 2312 creates the corresponding Item and Revision.
8. Converted datasets are attached to the created revision.
9. The imported structure becomes available within Teamcenter.

This process replaces several manual operations traditionally performed by engineering users and administrators.

---

## How to Test

1. Execute the PDM-to-PLM import tool.
2. Enter a valid source item code.
3. Select the desired CAD model.
4. Verify that the conversion workflow starts automatically.
5. Confirm that the NX Batch process is executed.
6. Wait for the migration workflow to finish.
7. Verify in Teamcenter 2312 that:
   - The Item was created successfully.
   - The Revision was created.
   - NX datasets were generated.
   - Converted CAD files are attached correctly.
   - The model can be opened from Teamcenter.

---

## Technical Notes

- Designed for Siemens Teamcenter 2312 environments.
- Supports automated CAD migration workflows.
- Integrates with existing PDM repositories.
- Uses SolidWorks as the source CAD platform.
- Uses NX and ImportSW2NX for model conversion.
- Supports unattended execution through NX Batch.
- Provides detailed logging for validation and troubleshooting purposes.

---

## Checklist

- [ ] Tested locally
- [ ] Tested in Teamcenter test environment
- [ ] PDM file discovery validated
- [ ] SolidWorks conversion validated
- [ ] NX Batch execution validated
- [ ] ImportSW2NX execution validated
- [ ] Teamcenter Item creation validated
- [ ] Teamcenter Revision creation validated
- [ ] Dataset attachment validated
- [ ] Logs reviewed
- [ ] Documentation updated
- [ ] No breaking changes introduced

---

## Additional Notes

This enhancement is intended to support the migration of engineering CAD data into Siemens Teamcenter 2312 by automating the conversion and import process. By integrating PDM retrieval, SolidWorks processing, NX conversion, and Teamcenter object creation into a single workflow, the solution significantly reduces processing time, minimizes human error, and improves traceability across the CAD lifecycle.
