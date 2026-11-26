#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <sys/wait.h>

#define MAX_LINE 1024
#define MAX_ARGS 64

// split the command into different arguments
int parse(char *input, char *args[])
{
    int i = 0;
    char *word = strtok(input, " \t\n");

    while (word != NULL && i < MAX_ARGS - 1)
    {
        args[i] = word;
        i++;
        word = strtok(NULL, " \t\n");
    }

    args[i] = NULL;
    return i;
}

// execute normal commands using fork and exec
int execute(char *args[])
{
    int status;
    pid_t p = fork();

    if (p == -1)
    {
        perror("fork");
        return 1;
    }

    if (p == 0)
    {
        execvp(args[0], args);

        if (errno == ENOENT)
            fprintf(stderr, "kshell: %s: command not found\n", args[0]);
        else
            perror("kshell");

        _exit(127);
    }
    else
    {
        waitpid(p, &status, 0);

        if (WIFEXITED(status))
            return WEXITSTATUS(status);

        return 1;
    }
}

int main(void)
{
    char input[MAX_LINE];
    char *args[MAX_ARGS];
    char path[1024];
    int status = 0;

    while (1)
    {
        printf("kshell> ");
        fflush(stdout);

        if (fgets(input, MAX_LINE, stdin) == NULL)
        {
            printf("\n");
            break;
        }

        int count = parse(input, args);

        if (count == 0)
            continue;

        // exit command
        if (strcmp(args[0], "exit") == 0)
        {
            if (args[1] != NULL)
                status = atoi(args[1]);

            break;
        }

        // change directory
        if (strcmp(args[0], "cd") == 0)
        {
            char *dir = args[1];

            if (dir == NULL)
                dir = getenv("HOME");

            if (dir == NULL || chdir(dir) != 0)
            {
                fprintf(stderr, "kshell: cd: ");
                perror(dir);
                status = 1;
            }
            else
            {
                status = 0;
            }

            continue;
        }

        // display current directory
        if (strcmp(args[0], "pwd") == 0)
        {
            if (getcwd(path, sizeof(path)) != NULL)
            {
                printf("%s\n", path);
                status = 0;
            }
            else
            {
                perror("pwd");
                status = 1;
            }

            continue;
        }

        // run other commands
        status = execute(args);
    }

    return status;
}
