## Summary

<!-- What does this PR do? Why is it needed? -->

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Improvement / refactor
- [ ] Documentation
- [ ] Security fix
- [ ] Infrastructure change

## Related repos / PRs

<!-- List any dependent PRs in aws-tf, aws-python-platform-template, or aws-web-platform-template -->

## Deployment order

<!-- Does this require coordinated deployment across repos? -->
- [ ] No cross-repo coordination needed
- [ ] Requires deploy order: aws-tf → backend → frontend

## Testing

<!-- What was tested and how? -->

- [ ] Tests added / updated
- [ ] Tested locally
- [ ] Tested in dev environment

## Checklist

- [ ] `terraform fmt` / `ruff` / `next lint` passes
- [ ] No secrets or credentials in this PR
- [ ] `contracts/api-contract.yaml` updated if API changed
- [ ] `contracts/ssm-parameters.yaml` updated if new SSM params added
- [ ] `platform.yaml` updated if new repos or roles added
- [ ] `NEXT_PUBLIC_API_BASE_URL` / backend URL changes reflected in frontend
