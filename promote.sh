#!/bin/bash

# Nombre de la rama de la que deseas extraer los commits
branch_name="master"

# Verificar el último tag en la rama master
latest_tag=$(git describe --tags --abbrev=0 origin/master)

if [ -z "$latest_tag" ]; then
  echo "No se encontraron tags en la rama master. Asegúrate de que haya al menos un tag para calcular la próxima versión."
  exit 1
fi

# Obtener la última versión y separarla en partes (mayor, menor, parche)
version_parts=($(echo $latest_tag | tr '.' ' '))
major=${version_parts[0]}
minor=${version_parts[1]}
patch=${version_parts[2]}

# Función para incrementar la versión
increment_version() {
  local part="$1"
  local value="$2"
  eval "$part=\$(($part + $value))"
}

# Verificar si hay nuevos commits desde el último tag
if [ -z "$(git log $latest_tag..$branch_name)" ]; then
  echo "No hay nuevos commits desde el último tag."
  exit 0
fi

# Archivo de salida para el resumen de cambios
output_file="CHANGELOG.md"

# Función para agregar commits a la categoría correspondiente
add_commits_to_categories() {
  local category_commits=$(git log --oneline $branch_name --grep="^fix:" | sed 's/^fix://' | sed 's/ /: /')
  if [ -n "$category_commits" ]; then
    increment_version "patch" 1
    # Reemplazar {{version}} con la versión actual
    sed -i "s/{{version}}/$next_version/g" "$output_file"
    echo >> $output_file
    echo "# $next_version" >> $output_file
    echo >> $output_file
    echo "### Bug Fixes" >> $output_file
    echo >> $output_file
    echo "$category_commits" >> $output_file
    echo >> $output_file
  fi

  local feature_commits=$(git log --oneline $branch_name --invert-grep --grep="^fix:")
  if [ -n "$feature_commits" ]; then
    increment_version "minor" 1
    # Reemplazar {{version}} con la versión actual
    sed -i "s/{{version}}/$next_version/g" "$output_file"
    echo >> $output_file
    echo "# $next_version" >> $output_file
    echo >> $output_file
    echo "### New Features" >> $output_file
    echo >> $output_file
    echo "$feature_commits" >> $output_file
    echo >> $output_file
  fi
}

# Archivo de salida para el resumen de cambios
output_file="CHANGELOG.md"

# Obtener cambios mayores (features) y menores (fixes)
add_commits_to_categories

# Generar la próxima versión
next_version="v$major.$minor.$patch"  # Agrega "v" a la versión

# Reemplazar {{version}} con la versión actual
sed -i "s/{{version}}/$next_version/g" "$output_file"

# Crear una rama para desarrollo futuro
future_branch="future_$next_version-snapshot"
git checkout -b "$future_branch"
git push origin "$future_branch"

# Crear una rama para la versión de lanzamiento
release_branch="release_$next_version"
git checkout -b "$release_branch"
git push origin "$release_branch"

# Agregar un tag con la nueva versión
git tag -a "$next_version" -m "Versión $next_version"

# Publicar el resumen de cambios en GitHub
# Reemplaza 'nombre_usuario' y 'nombre_repositorio' con tus propios valores
github_user="rulmaker"
github_repo="examtaker"
git clone "https://github.com/$github_user/$github_repo.git" --depth 1 --branch master --single-branch "$output_file"
cp "$output_file" .  # Copia el archivo CHANGELOG.md al directorio actual
git add "$output_file"
git commit -m "Añadir resumen de cambios para la versión $next_version"
git push origin main

echo "Las ramas $future_branch y $release_branch se han creado y enviado a GitHub."
echo "Se ha agregado un tag '$next_version' al repositorio."
