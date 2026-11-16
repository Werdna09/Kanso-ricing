# Kanso Fish — two clean, understated lines, preserving last command status.
# Loaded directly by Kanso; no Amber or Crylia prompt is required.
function fish_prompt
    set -l previous $status
    set -l ink 9ABFBE
    set -l paper F7E9C9
    set -l accent D5CFAD
    set -l path_color A8BEAD
    set -l pwd (prompt_pwd)
    set -l gitpart ''
    if command -sq git
        set -l branch (command git branch --show-current 2>/dev/null)
        if test -n "$branch"
            set gitpart "  ·  $branch"
        end
    end
    printf '%s%s%s%s\n' (set_color $path_color) "$pwd" (set_color $ink) "$gitpart"
    if test $previous -ne 0
        printf '%s❯%s ' (set_color C48673) (set_color normal)
    else
        printf '%s❯%s ' (set_color $accent) (set_color normal)
    end
end

function fish_right_prompt
    printf '%s%s%s' (set_color 78999B) (date '+%H:%M') (set_color normal)
end
