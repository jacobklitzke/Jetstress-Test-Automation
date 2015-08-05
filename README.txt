This script will automate the process of running Exchange Jetstress tests. This script is capable of running Performance, 
Backup, Soft Recovery, and Stress tests. 

To run this script, copy the powershell script and JetStressConfig.xml file to the Exchange Jetstress root directory. 

When the script is launched, you will select which test to run, or all the tests can be run in succession.

The script will then prompt the user for all the input parameters for the Jetstres tests. 

This script is also capable of checking whether or not a test passes. If a test does not pass, the user will have the 
option to alter the thread count and run the test again.

Once the test is complete, the results will be available in the respective test's folder. (e.g. performance test = Performance Results folder).