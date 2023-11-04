import json
import random
import os
import time
import sys


def cls():
    os.system('cls' if os.name == 'nt' else 'clear')


def wait_key():
    result = None
    if os.name == 'nt':
        import msvcrt
        result = msvcrt.getwch()
    else:
        import termios
        fd = sys.stdin.fileno()
        oldterm = termios.tcgetattr(fd)
        newattr = termios.tcgetattr(fd)
        newattr[3] = newattr[3] & ~termios.ICANON & ~termios.ECHO
        termios.tcsetattr(fd, termios.TCSANOW, newattr)
        try:
            result = sys.stdin.read(1)
        except IOError: pass
        finally: termios.tcsetattr(fd, termios.TCSAFLUSH, oldterm)
    return result


class PriorityRandomGenerator:
    def __init__(self, n_patterns, priorities):
        self.indices = [x for x in range(n_patterns)]
        self.priorities = priorities
        self.n = len(self.priorities)

    def prefixSums(self):
        p = [0] * (self.n + 1)
        for k in range(1, self.n + 1):
            p[k] = p[k - 1] + self.priorities[k - 1]
        return p

    def pickIndex(self):
        preS = self.prefixSums()
        sumP = sum(self.priorities)
        p_i = random.uniform(0, sumP)
        for i in range(0, len(preS)):
            if preS[i] < p_i < preS[i + 1]:
                return i


def renderPatternBranching(answer, pattern):
    int_small_var_set = ["x", "y", "n", "i", "j"]
    int_var_name = db['Variables']['Int Variable Names']
    int_rust_var_type = db['Variables']['Rust Int Variable Types']
    render = answer
    for p in pattern:
        if p == "[random int variable]":
            r = random.randint(1, 3)
            if r == 1: render = render.replace(p, chr(random.randint(ord('a'), ord('z'))))
            elif r == 2: render = render.replace(p, int_var_name[random.randint(0, len(int_var_name) - 1)])
            elif r == 3: render = render.replace(p, int_small_var_set[random.randint(0, len(int_small_var_set) - 1)])
        if p == "[random integer]":
            r = random.randint(1, 4)
            if r == 1: render = render.replace(p, str(random.randint(0, 9)))
            elif r == 2: render = render.replace(p, str(random.randint(0, 9999)))
            elif r == 3: render = render.replace(p, str(random.randint(0, 999999)))
            elif r == 4: render = render.replace(p, str(random.randint(0, 99)))
        if p == "[random rust data type]":
            render = render.replace(p, int_rust_var_type[random.randint(0, len(int_rust_var_type) - 1)])
    return render.strip()


def renderPatternOptions(answer, pattern):
    render = answer
    for p in pattern:
        if p in answer:
            options = p.replace("[", "").replace("]", "").split("|")
            option = options[random.randint(0, len(options) - 1)]
            if option == "None": render = render.replace(p, "")
            else: render = render.replace(p, option)
    return render.strip()


if __name__ == '__main__':
    with open('db.json') as f:
        db = json.load(f)

    languages = {}
    for lang in db['Language']:
        languages[lang] = 1
    prev_question_number = question_number = 0
    while True:
        lang_list = [[lang, languages[lang]] for lang in languages.keys()]
        prg_language = PriorityRandomGenerator(len(lang_list), [x[1] for x in lang_list])
        language = lang_list[prg_language.pickIndex()][0]
        correct_answers = db['Variables']['Declaration']['Multi-Choice']['Answers']['Correct'][language]
        answer_pattern_groups = db['Variables']['Declaration']['Multi-Choice']['Answers']['Incorrect']
        answer_patterns = [[p['Pattern'], p['Priority']] for p in answer_pattern_groups]
        questions = db['Variables']['Declaration']['Multi-Choice']['Question']
        q_type = db['Variables']['Declaration']['Multi-Choice']['Type']
        q_subtype = db['Variables']['Declaration']['Multi-Choice']['Sub-Type']
        patterns_A = db['Variables']['Variable Permutations']
        patterns_B = db['Variables']['Random Variables']
        question_range = len(questions) - 1
        while question_number == prev_question_number:
            question_number = random.randint(0, question_range)
        prev_question_number = question_number
        question = questions[question_number].replace("[language]", language)
        correct_answer = correct_answers[0]
        if len(correct_answers) > 1:
            correct_answer = correct_answers[random.randint(0, len(correct_answers) - 1)]
        choices = [[correct_answer, 1]]
        prg_choice = PriorityRandomGenerator(len(answer_patterns), [x[1] for x in answer_patterns])
        while len(choices) < 5:
            incorrect_answer = renderPatternOptions([x[0] for x in answer_patterns][prg_choice.pickIndex()], patterns_A)
            if incorrect_answer in [x[0] for x in choices]: continue
            if incorrect_answer in correct_answers: continue
            choices.append([incorrect_answer, 0])
        for j in range(len(choices)):
            choices[j][0] = renderPatternBranching(choices[j][0], patterns_B)
        random.shuffle(choices)

        while True:
            cls()
            print()
            print("Language:", language, "-", q_subtype)
            print("\n", question, "\n")
            for i, c in enumerate([x[0] for x in choices]):
                print(f"\t{i + 1}.", c)
            a = wait_key()
            if a == '\x1b': exit(0)
            if a.isnumeric():
                print(a)
                if 0 < int(a) < len(choices) + 1:
                    if choices[int(a) - 1][1] == 1:
                        if languages[language] > 1: languages[language] -= 1
                        break
                    else:
                        cls()
                        print("\n\tWrong Answer")
                        languages[language] += 1
                        time.sleep(1)
                        continue
                else:
                    cls()
                    print("\n\tOut of Range Input")
                    time.sleep(1)
                    continue
            else:
                cls()
                print("\n\tInvalid Input")
                time.sleep(1)
                continue
