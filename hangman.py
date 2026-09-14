#!/usr/bin/env python3
import sys
import json
import random
from pathlib import Path
from PyQt5.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                             QHBoxLayout, QPushButton, QLabel, QComboBox, 
                             QMessageBox)
from PyQt5.QtCore import Qt, QTimer
from PyQt5.QtGui import QFont, QKeyEvent

WORDS = {
    "animals": ["elephant", "giraffe", "penguin", "cheetah", "kangaroo", 
                "rhinoceros", "crocodile", "flamingo", "octopus", "aardvark", "lion",
                "deer", "moose", "leopard", "hippopotamus", "tiger", "badger", "groundhog",
                "wolverine", "squirrel", "antelope", "zebra", "rabbit", "jackrabbit", "nutria",
                "raccoon", "skunk", "turtle", "monkey", "orangutan", "platypus", "meerkat", 
                "mongoose","wombat","elk","waterbuffalo","koala"],
    "birds": ["sparrow", "eagle", "parrot", "penguin", "owl", "flamingo", "peacock", "seagull",
              "pigeon", "robin","bluejay","cardinal","vulture","hawk","blackbird","swan",
              "goose","falcon","condor","raven","roadrunner","mockingbird","finch","parakeet"],
    "aquatic": ["dolphin", "shark", "octopus", "squid", "whale", "beluga", "crab", "eel", "stingray",
                "manta ray", "orca", "starfish","jellyfish", "narwhal", "swordfish", "tuna",
                "salmon","cod","flounder","trout","halibut","mackerel","bass","sardine"],
    "foods": ["pizza", "spaghetti", "hamburger", "sushi", "burrito", "lasagna", "vindalu",
              "chocolate", "sandwich", "pancake", "tacos", "yakisoba", "sukiyaki", "calzone",
                "fetuccini", "steak", "shrimp","enchilada","fajitas"],
    "american_cities": ["new york", "los angeles", "chicago", "houston", "phoenix", "philadelphia",
                "san antonio", "san diego", "dallas", "san jose","toledo","miami","atlanta","boston",
                "austin","raleigh","charlotte","orlando","minneapolis","seattle","denver","portland",
                "nashville","portland","oakland","tampa","mobile","hartford","cheyenne","boulder",
                "sacramento","salt lake city","billings","birmingham","richmond","williamsburg","detroit"],
    "capital_cities": ["paris", "tokyo", "london", "sydney", "cairo", "moscow", "copenhagen",
               "toronto", "berlin", "stockholm", "amsterdam", "antwerp", "brussels",
                "beijing", "ankara", "athens", "rome", "zurich", "toronto", "montreal",
                "vancouver","reykjavik","hanoi","bangkok","kuala lumpur","singapore",
                "hiroshima","oslo","lisbon","cape town","nagasaki","auckland",
                "mexico city","kinshasa","lagos","jakarta","addis ababa","nairobi",
                "abuja","damascus","riyadh","doha","kathmandu","helsinki","osaka","amman"],
    "countries": ["brazil", "canada", "france", "japan", "mexico", "spain", "america",
                  "united states", "united kingdom","ireland","mongolia",
                  "egypt", "india", "australia", "germany","russia","estonia","latvia",
                "lithuania", "denmark", "sweden", "chile", "iran", "iraq", "syria", "israel",
                "jordan", "lebanon", "turkey", "greece", "italy", "switzerland", "bulgaria",
                "mauritius","macedonia","albania","serbia","montenegro","kosovo","slovenia",
                "croatia","slovakia","hungary","poland","belarus","ukraine","uruguay",
                "paraguay","venezuela","cuba", "argentina", "colombia", "bolivia", "ecuador",
                "peru", "chile", "romania", "czech republic", "finland", "austria", "australia",
                "new zealand"]
}

THEMES = {
    "Ocean Breeze": {"bg": "#E3F2FD", "primary": "#1565C0", "secondary": "#0277BD", "text": "#01579B"},
    "Sunset Glow": {"bg": "#FFF3E0", "primary": "#F57C00", "secondary": "#FB8C00", "text": "#E65100"},
    "Cotton Candy": {"bg": "#FCE4EC", "primary": "#C2185B", "secondary": "#D81B60", "text": "#AD1457"},
    "Forest Mist": {"bg": "#E8F5E9", "primary": "#2E7D32", "secondary": "#388E3C", "text": "#1B5E20"},
    "Lavender Dream": {"bg": "#F3E5F5", "primary": "#7B1FA2", "secondary": "#8E24AA", "text": "#6A1B9A"},
    "Midnight Sky": {"bg": "#E8EAF6", "primary": "#283593", "secondary": "#3949AB", "text": "#1A237E"},
    "Coral Reef": {"bg": "#FBE9E7", "primary": "#D84315", "secondary": "#E64A19", "text": "#BF360C"},
    "Mint Fresh": {"bg": "#E0F2F1", "primary": "#00695C", "secondary": "#00897B", "text": "#004D40"}
}

HANGMAN_STAGES = [
    """
       ------
       |    |
       |
       |
       |
       |
    --------
    """,
    """
       ------
       |    |
       |    O
       |
       |
       |
    --------
    """,
    """
       ------
       |    |
       |    O
       |    |
       |
       |
    --------
    """,
    """
       ------
       |    |
       |    O
       |   /|
       |
       |
    --------
    """,
    """
       ------
       |    |
       |    O
       |   /|\\
       |
       |
    --------
    """,
    """
       ------
       |    |
       |    O
       |   /|\\
       |   /
       |
    --------
    """,
    """
       ------
       |    |
       |    O
       |   /|\\
       |   / \\
       |
    --------
    """
]

class HangmanGame(QMainWindow):
    def __init__(self):
        super().__init__()
        self.score_file = Path.home() / ".hangman_scores.json"
        self.load_scores()
        self.current_theme = "Ocean Breeze"
        self.init_ui()
        self.apply_theme()
        self.new_game()
        
    def load_scores(self):
        if self.score_file.exists():
            with open(self.score_file, 'r') as f:
                self.scores = json.load(f)
        else:
            self.scores = {"wins": 0, "losses": 0}
    
    def save_scores(self):
        with open(self.score_file, 'w') as f:
            json.dump(self.scores, f)
    
    def init_ui(self):
        self.setWindowTitle("Hangman Game")
        self.setGeometry(100, 100, 600, 500)
        self.setFocusPolicy(Qt.StrongFocus)
        
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        layout = QVBoxLayout()
        
        # Score display
        self.score_label = QLabel()
        self.score_label.setFont(QFont("Arial", 12, QFont.Bold))
        self.update_score_display()
        layout.addWidget(self.score_label, alignment=Qt.AlignCenter)
        
        # Category and theme selectors
        cat_layout = QHBoxLayout()
        cat_layout.addWidget(QLabel("Category:"))
        self.category_combo = QComboBox()
        self.category_combo.addItems(WORDS.keys())
        self.category_combo.currentTextChanged.connect(self.new_game)
        cat_layout.addWidget(self.category_combo)
        cat_layout.addStretch()
        cat_layout.addWidget(QLabel("Theme:"))
        self.theme_combo = QComboBox()
        self.theme_combo.addItems(THEMES.keys())
        self.theme_combo.setCurrentText(self.current_theme)
        self.theme_combo.currentTextChanged.connect(self.change_theme)
        cat_layout.addWidget(self.theme_combo)
        layout.addLayout(cat_layout)
        
        # Hangman display
        self.hangman_label = QLabel()
        self.hangman_label.setFont(QFont("Courier", 14))
        self.hangman_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(self.hangman_label)
        
        # Word display
        self.word_label = QLabel()
        self.word_label.setFont(QFont("Arial", 24, QFont.Bold))
        self.word_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(self.word_label)
        
        # Letters tried
        self.letters_label = QLabel()
        self.letters_label.setFont(QFont("Arial", 10))
        self.letters_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(self.letters_label)
        
        # Letter buttons
        button_layout = QVBoxLayout()
        self.letter_buttons = {}
        
        rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        for row in rows:
            row_layout = QHBoxLayout()
            row_layout.addStretch()
            for letter in row:
                btn = QPushButton(letter.upper())
                btn.setFixedSize(40, 40)
                btn.clicked.connect(lambda checked, l=letter: self.guess_letter(l))
                self.letter_buttons[letter] = btn
                row_layout.addWidget(btn)
            row_layout.addStretch()
            button_layout.addLayout(row_layout)
        
        layout.addLayout(button_layout)
        
        # New game button
        new_game_btn = QPushButton("New Game")
        new_game_btn.clicked.connect(self.new_game)
        layout.addWidget(new_game_btn)
        
        central_widget.setLayout(layout)
    
    def keyPressEvent(self, event: QKeyEvent):
        key = event.text().lower()
        if key.isalpha() and len(key) == 1 and key in self.letter_buttons:
            self.guess_letter(key)
    
    def change_theme(self, theme_name):
        self.current_theme = theme_name
        self.apply_theme()
    
    def apply_theme(self):
        theme = THEMES[self.current_theme]
        self.setStyleSheet(f"""
            QMainWindow {{
                background-color: {theme['bg']};
            }}
            QWidget {{
                background-color: {theme['bg']};
                color: {theme['text']};
            }}
            QLabel {{
                color: {theme['text']};
            }}
            QPushButton {{
                background-color: {theme['primary']};
                color: white;
                border: 2px solid {theme['secondary']};
                border-radius: 5px;
                padding: 5px;
                font-weight: bold;
            }}
            QPushButton:hover {{
                background-color: {theme['secondary']};
            }}
            QPushButton:disabled {{
                background-color: #CCCCCC;
                color: #666666;
                border: 2px solid #999999;
            }}
            QComboBox {{
                background-color: white;
                color: {theme['text']};
                border: 2px solid {theme['primary']};
                border-radius: 3px;
                padding: 3px;
            }}
        """)
    
    def update_score_display(self):
        self.score_label.setText(
            f"Wins: {self.scores['wins']}  |  Losses: {self.scores['losses']}"
        )
    
    def new_game(self):
        category = self.category_combo.currentText()
        self.word = random.choice(WORDS[category])
        self.guessed_letters = set()
        self.wrong_guesses = 0
        self.game_over = False
        
        for btn in self.letter_buttons.values():
            btn.setEnabled(True)
        
        self.update_display()
    
    def guess_letter(self, letter):
        if self.game_over or letter in self.guessed_letters:
            return
        
        self.guessed_letters.add(letter)
        self.letter_buttons[letter].setEnabled(False)
        
        if letter not in self.word:
            self.wrong_guesses += 1
        
        self.update_display()
        self.check_game_state()
    
    def update_display(self):
        # Update hangman
        self.hangman_label.setText(HANGMAN_STAGES[self.wrong_guesses])
        
        # Update word
        display_word = " ".join(
            letter.upper() if letter in self.guessed_letters else "_"
            for letter in self.word
        )
        self.word_label.setText(display_word)
        
        # Update letters tried
        if self.guessed_letters:
            sorted_letters = sorted(self.guessed_letters)
            self.letters_label.setText(f"Tried: {', '.join(l.upper() for l in sorted_letters)}")
        else:
            self.letters_label.setText("Tried: none")
    
    def check_game_state(self):
        if self.wrong_guesses >= len(HANGMAN_STAGES) - 1:
            self.game_over = True
            self.scores["losses"] += 1
            self.save_scores()
            self.update_score_display()
            QMessageBox.information(self, "Game Over", 
                                   f"You lost! The word was: {self.word.upper()}")
            QTimer.singleShot(100, self.new_game)
        
        elif all(letter in self.guessed_letters for letter in self.word):
            self.game_over = True
            self.scores["wins"] += 1
            self.save_scores()
            self.update_score_display()
            QMessageBox.information(self, "Congratulations", 
                                   f"You won! The word was: {self.word.upper()}")
            QTimer.singleShot(100, self.new_game)

if __name__ == "__main__":
    app = QApplication(sys.argv)
    game = HangmanGame()
    game.show()
    sys.exit(app.exec_())
