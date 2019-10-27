# Longest Common Subsequence (LCS) problem
# Reference: https://en.wikipedia.org/wiki/Longest_common_subsequence_problem

import os

# Complete the commonChild function below.
def commonChild(s1, s2):
    """Algorithm 1"""

    m, n = len(s1), len(s2)
    prev, cur = [0] * (n+1), [0] * (n+1)

    for i in range(1, m+1):
        for j in range(1, n+1):
            if s1[i-1] == s2[j-1]:
                cur[j] = 1 + prev[j-1]
            else:
                # Max between cur and prev
                if cur[j-1] > prev[j]:
                    cur[j] = cur[j-1]
                else:
                    cur[j] = prev[j]

        cur, prev = prev, cur

    return prev[n]


    """Algorithm 2"""

    # start = 0
    # end = len(s1)

    # # Tracks matching characters at the beginning.
    # while start <= end - 1 and s1[start] == s2[start]:
    #     start += 1

    # # Tracks matching characters at the end.
    # while start <= end - 1 and s1[end-1] == s2[end-1]:
    #     end -= 1

    # # A matrix with two rows is enough. Saves memory.
    # matrix = [[0 for i in range(end - start + 1)]] * 2

    # # Algorithm implemented from the wikipedia article.
    # for i in range(start, end):
    #     for j in range(start, end):
    #         if s2[i] == s1[j]:
    #             matrix[1][j-start+1] += (matrix[0][j-start] + 1)
    #         else:
    #             matrix[1][j-start+1] = max(matrix[1][j-start], matrix[0][j-start+1])
    #     matrix[0] = matrix[1]
    #     matrix[1] = [0] * (end - start + 1)

    # return matrix[0][-1] + len(s1) + start - end


    """Algorithm 3"""
    # A way to think about it is as follows:
    # We increment by 1, where there's a match
    # And carry over where there isn't a match
    #    0 s h i n c h a n
    # 0 0 0 0 0 0 0 0 0 0     We start off with length 0
    # n 0 0 0 0 1 0 0 0 1     We matched at 2 'n''s, so we  +1
    # o 0 0 0 0 1 1 1 1 1     No matches, but carry over lens
    # h 0 0 1 1 1 1 1 1 1     2 'h' matches + carry over
    # a 0 0 1 1 1 1 1 2 2     1 'a' match
    # r 0 0 1 1 1 1 1 2 2     Carry over: tracks at what idx
    # a 0 0 1 1 1 1 1 2 2     1st found match, any match after
    # a 0 0 1 1 1 1 1 2 2     +1 to prev ones. Notice more a's
    # a 0 0 1 1 1 1 1 2 2     don't affect cts bc there's no more
		#          a's after index 6 in shinchan.

    # # both strings are the same length
    # n = len(s1)

    # # a 2D array, where we keep track of lengths
    # lengths = [[0 for i in range(n+1)] for j in range(n+1)]

    # for i in range(n):
    #     for j in range(n):
    #         if s1[i] == s2[j]:
    #             # if the letters are the same, then we take the longest
    #             # length from before and add 1
    #             lengths[i+1][j+1] = lengths[i][j] + 1
    #         else:
    #             # if they aren't, we carry on the max length we had so far
    #             lengths[i+1][j+1] = max(lengths[i+1][j], lengths[i][j+1])
    # return lengths[n][n]

if __name__ == '__main__':
    fptr = open(os.environ['OUTPUT_PATH'], 'w')

    s1 = input()

    s2 = input()

    result = commonChild(s1, s2)

    fptr.write(str(result) + '\n')

    fptr.close()