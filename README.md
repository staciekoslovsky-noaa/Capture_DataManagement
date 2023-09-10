# Capture Data Management

Code numbered 0+ are intended to be run sequentially as the data are available for processing. Code numbered 99 are stored for longetivity, but are intended to only be run once to address a specific issue or run as needed, depending on the intent of the code.

The data management processing code is as follows:
* **Capture_01_AssignEvent_AfterSampleResultsImported.txt** - used to assign capture sample results to capture event data in the DB after new sample results are imported into the DB; this code is run in PGAdmin