# ADR 0005: este root es 100% Railway — su base de datos es railway-managed (main.tf), nunca
# la de Azure ya existente. Este archivo queda vacio a proposito (se sigue pasando con
# -var-file por consistencia con el resto del pipeline, pero no declara nada: no hay ninguna
# variable de Azure en variables.tf que rellenar aqui).
