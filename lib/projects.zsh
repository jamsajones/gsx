# gpane project management
# Handles project resolution, listing, and selection

# Resolve a project name or path to absolute path
# For virtual projects, returns configured directory or current directory
resolve_project_dir() {
  local input=$1
  local resolved

  if [[ "${input}" = /* ]]; then
    # Absolute path
    if [[ ! -d "${input}" ]]; then
      echo "Error: Path '${input}' does not exist" >&2
      return 1
    fi
    resolved=$(cd "${input}" && pwd)
  elif [[ "${input}" = ./* || "${input}" = ../* ]]; then
    # Relative path (./help, ../project) - resolve from current directory
    if [[ ! -d "${input}" ]]; then
      echo "Error: Path '${input}' does not exist" >&2
      return 1
    fi
    resolved=$(cd "${input}" && pwd)
  else
    # Project name - check virtual projects first, then PROJECTS_ROOT, then current directory
    if is_virtual_project "${input}"; then
      # Virtual project - use configured directory or current directory
      local vdir
      vdir=$(get_virtual_project_dir "${input}")
      if [[ -n "${vdir}" ]]; then
        if [[ ! -d "${vdir}" ]]; then
          echo "Error: Virtual project directory '${vdir}' does not exist" >&2
          return 1
        fi
        resolved=$(cd "${vdir}" && pwd)
      else
        # No directory configured - use current directory
        resolved="${PWD}"
      fi
    elif [[ -d "${PROJECTS_ROOT}/${input}" ]]; then
      resolved=$(cd "${PROJECTS_ROOT}/${input}" && pwd)
    elif [[ -d "${input}" ]]; then
      # Fallback: try current directory
      resolved=$(cd "${input}" && pwd)
    else
      echo "Error: Project '${input}' not found in '${PROJECTS_ROOT}' or current directory" >&2
      return 1
    fi
  fi

  printf '%s\n' "${resolved}"
}

# List all projects (for gpane list command)
list_projects() {
  if [[ ! -d "${PROJECTS_ROOT}" ]]; then
    echo "Error: Projects root '${PROJECTS_ROOT}' does not exist" >&2
    return 1
  fi

  echo "Projects in ${PROJECTS_ROOT}:"
  echo ""

  local dir count=0
  while IFS= read -r dir; do
    printf '  %s\n' "$(basename "${dir}")"
    count=$((count + 1))
  done < <(find "${PROJECTS_ROOT}" -mindepth 1 -maxdepth 1 -type d ! -name ".*" | sort)

  # List virtual projects
  if (( ${#VIRTUAL_PROJECTS[@]} > 0 )); then
    echo ""
    echo "Virtual projects:"
    echo ""
    local name
    for name in ${(ko)VIRTUAL_PROJECTS}; do
      printf '  %s\n' "${name}"
      count=$((count + 1))
    done
  fi

  echo ""
  echo "${count} project(s) found"
}

# Interactive project picker
# Sets global SELECTED_PROJECTS array instead of printing (to avoid subshell issues)
# For virtual projects, stores "virtual:<name>" to distinguish from directory paths
interactive_select() {
  local -a projects
  local -i index=1
  local dir

  # Reset global
  typeset -ga SELECTED_PROJECTS
  SELECTED_PROJECTS=()

  echo ""
  echo "Projects in ${PROJECTS_ROOT}:"
  echo ""

  while IFS= read -r dir; do
    projects+=("${dir}")
    printf '  %2d) %s\n' "${index}" "$(basename "${dir}")"
    index=$((index + 1))
  done < <(find "${PROJECTS_ROOT}" -mindepth 1 -maxdepth 1 -type d ! -name ".*" | sort)

  # Add virtual projects
  if (( ${#VIRTUAL_PROJECTS[@]} > 0 )); then
    echo ""
    echo "Virtual projects:"
    echo ""
    local name
    for name in ${(ko)VIRTUAL_PROJECTS}; do
      # Store as "virtual:<name>" marker
      projects+=("virtual:${name}")
      printf '  %2d) %s\n' "${index}" "${name}"
      index=$((index + 1))
    done
  fi

  if (( ${#projects[@]} == 0 )); then
    echo "No projects found."
    return 1
  fi

  echo ""
  local selection=""
  prompt_input 'Select project(s) (e.g., "1" or "1 3 5"): ' selection

  if [[ -z "${selection}" ]]; then
    echo "No selection made."
    return 1
  fi

  # Validate and collect selections
  local token
  for token in ${=selection}; do
    if ! [[ "${token}" == <-> ]]; then
      echo "Invalid: '${token}'" >&2
      return 1
    fi
    local -i idx=${token}
    if (( idx < 1 || idx > ${#projects[@]} )); then
      echo "Out of range: '${token}'" >&2
      return 1
    fi
    SELECTED_PROJECTS+=("${projects[idx]}")
  done

  (( ${#SELECTED_PROJECTS[@]} > 0 ))
}
