import sys

n = int(sys.argv[1])

parsed_env_secrets = []

for i in range(1, n + 1):
    with open(f"./team{i}.phreaking.secrets.txt") as f:
        lines = [line for line in f]
        parsed_env_secrets.append(lines[0].replace("PHREAKING_", f"PHREAKING_{i}_"))
        parsed_env_secrets.append(lines[1].replace("PHREAKING_", f"PHREAKING_{i}_"))


with open("checker.env", "w") as fp:
    fp.writelines(parsed_env_secrets)
