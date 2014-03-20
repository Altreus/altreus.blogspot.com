(function() {
    var template;

    function proxy(obj, method) {
        return function() {
            obj[method]();
        };
    }

    function RegexMonkey(target) {
        this.svg = Snap(target);
        this.frame = 0;

        this.stringRep = template.select('.string-rep').clone();
        this.regexRep = template.select('.regex-rep').clone();

        this.stringRep.select(':first-child').attr({ width: 4 });
        this.stringRep.select(':nth-child(2)').attr({ width: 2 });

        this.regexRep.select(':first-child').attr({ width: 4 });
        this.regexRep.select(':nth-child(2)').attr({ width: 2 });

        this.regexRep.transform(new Snap.Matrix().translate(0, 36));

        this.controls = template.select('#controls').clone();
        this.controls.select('.prev-frame').click(proxy(this, 'prevFrame'));
        this.controls.select('.next-frame').click(proxy(this, 'nextFrame'));

        this.controls.transform(new Snap.Matrix().translate(16, 92));

        this.svg.append(this.stringRep);
        this.svg.append(this.regexRep);
        this.svg.append(this.controls);
    };

    RegexMonkey.init = function(selector) {
        template = Snap(selector);
    }

    RegexMonkey.prototype = {
        setString: function(string) {
            this.string = string;
            setSwatches.call(this, this.stringRep, string.split(''));
        },
        setRegex: function(tokenArray) {
            this.regex = tokenArray;
            setSwatches.call(this, this.regexRep, tokenArray);
        },
        reset: function() {
            var reticule = this.reticule;
            if (!reticule) {
                reticule = template.select('#reticule').use();
                reticule.attr({ class: 'reticule' });
                this.svg.append(reticule);
            }

            this.reticule = reticule;

            this.stringAt = this.regexAt = 0;
        },
        nextFrame: function() {
            if (this.stringAt == this.string.length - 1 || this.regexAt == this.regex.length - 1) {
                return;
            }

            if (this.string.charAt(this.stringAt).match(this.regex[this.regexAt])) {
                this.reticule.transform(new Snap.Matrix().translate(28, 0).add(this.reticule.transform().globalMatrix));
                this.stringAt++;
                this.regexAt++;
            }
            else {
                var m = new Snap.Matrix().translate(28,0);
                this.regexRep.transform(m.clone().add(this.regexRep.transform().globalMatrix));
                this.reticule.transform(m.clone().add(this.reticule.transform().globalMatrix));
                this.stringAt++;
            }
        },
        prevFrame: function() {
        }
    };

    function setSwatches(rep, chars) {
        rep.select(':first-child').attr({
            width: chars.length * (24+4) + 4
        });
        rep.select(':nth-child(2)').attr({
            width: chars.length * (24+4) + 2
        });
        var swatch = template.select('#letterSwatch');

        var i, copy, letter;
        for (i in chars) {
            copy = swatch.use();
            copy.attr({
                fill: rep.select(':first-child').attr('fill')
            });
            copy.transform(new Snap.Matrix().translate((i*(24+4))+4, 4));

            rep.append(copy);

            letter = this.svg.text(0, 0, chars[i]);
            letter.attr({
                'text-anchor': 'middle',
                'dominant-baseline': 'central'
            });
            letter.transform(new Snap.Matrix().translate((i*(24+4))+4+12, 4+12));

            rep.append(letter);
        }
    }

    window.RegexMonkey = RegexMonkey;
})();
