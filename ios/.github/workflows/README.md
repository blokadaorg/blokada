How to redo the certificates bs:

- in Apple panel, remove provisioning profiles and cert related to app + netx
- Create new cert (ios distribution, not apple dist), and import it to your local mac keychain
- in Keychain Access, select that cert (in My certificates), and right click Export, save .p12
- cat it and base64, paste that to github actions secrets
- do not create provisioning profile, the fastlane will create them
