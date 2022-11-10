function work --description "work on a git project with worktrees" --argument-names cmd request
  set --function root "$WORK_ROOT"
  if test -z "$root"
    set root "$HOME/Projects"
  end
  mkdir -p "$root"
  
  function _work_usage --inherit-variable root
    echo "Work on a git repo using worktrees and a bare clone"
    echo ""
    echo "USAGE"
    echo "  work <cmd> [arg]"
    echo ""
    echo "COMMANDS"
    echo "  repo <owner>/<repo>:    bare clone a repo and cd to it"
    echo "  branch [branch]:        create a worktree from a new or existing branch"
    echo "  pull [number]:          create a worktree from a pull request"
    echo ""
    return 1
  end
  
  function _work_repo --inherit-variable root --argument-names repo
    if not test -d "$root/$repo"
      git clone --bare \
        --config remote.origin.fetch="+refs/heads/*:refs/remotes/origin/*" \
        --config remote.origin.fetch="+refs/pull/*/head:refs/remotes/origin/pull/*" \
        "git@github.com:$repo" "$root/$repo"

      pushd "$root/$repo" >/dev/null
      mkdir -p pulls branches
      set --function default_branch (git symbolic-ref --short HEAD)
      set --function branch_dir (string replace -a / _ "$default_branch")
      git worktree add "./branches/$branch_dir" "$default_branch"
      popd >/dev/null
    end

    cd "$root/$repo"
  end
  
  function _work_branch --argument-names _branch
    set --function _pwd (pwd)
    while true
      if test (git -C "$_pwd" rev-parse --is-bare-repository) = "true"
        if test -d "$_pwd/branches"
          break
        end
      end

      set _pwd (dirname "$_pwd")
      if test "$_pwd" = /
        echo "bare clone not found. are you in the right directory?"
        return 1
      end
    end

    set --function branch $_branch
    if test -z "$branch"
      set --local available_branches (git -C "$_pwd" branch -a -vv |\
        grep '^\s*remotes/origin' |\
        grep -v '^\s*remotes/origin/pull/' |\
        string trim |\
        string replace -r '^remotes/origin/' '' |\
        string collect)

      set branch (echo $available_branches | fzf | string split ' ' -f1)
    end
    set --function branch_dir (string replace -a / _ $branch)
    echo "cleaned \"$branch\" to \"$branch_dir\""

    if not test -d "$_pwd/branches/$branch_dir"
      pushd "$_pwd" >/dev/null
      if git rev-parse --verify "$branch"
        git worktree add "./branches/$branch_dir" "$branch"
      else
        git worktree add "./branches/$branch_dir" -b "$branch"
      end
      popd >/dev/null
    end
    
    cd "$_pwd/branches/$branch_dir"
  end
  
  function _work_pull --argument-names _pull
    set --function _pwd (pwd)
    while true
      if test (git -C "$_pwd" rev-parse --is-bare-repository) = "true"
        if test -d "$_pwd/pulls"
          break
        end
      end

      set _pwd (dirname "$_pwd")
      if test "$_pwd" = /
        echo "bare clone not found. are you in the right directory?"
        return 1
      end
    end

    set --function pull $_pull
    if test -z "$pull"
      set --local available_pulls (git -C "$_pwd" branch -a -vv |\
        grep '^\s*remotes/origin/pull/' |\
        string trim |\
        string replace -r '^remotes/origin/pull/' '' |\
        sort -rn |\
        string collect)

      set pull (echo $available_pulls | fzf | string split ' ' -f1 | string replace 'pull/' '')
    end

    if not test -d "$_pwd/pulls/$pull"
      pushd "$_pwd" >/dev/null
      git worktree add "./pulls/$pull" "remotes/origin/pull/$pull"
      popd >/dev/null
    end
    
    cd "$_pwd/pulls/$pull_dir"
  end
  
  switch "$cmd"
    case "repo"
      _work_repo $request
    case "branch"
      _work_branch $request
    case "pull"
      _work_pull $request
    case '*'
      _work_usage
  end
end
