# npm-deep-scan
This is a small script to scan your project for affected packages by Shai Hulud 2.0 attack.


## How to

1. Make file executable:
   ```bash
   chmod +x deep-scan-from-xlsx.sh
   ```

2. Run script with project path:
   ```bash
   ./deep-scan-from-xlsx.sh /path/to/npm/project
   ```

3. Inspect created `deep-scan-report.json` for affected packages.
