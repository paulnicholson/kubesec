SHELL := /bin/bash
VERSION := $(shell git describe --tags)

fetch:
	go get \
	github.com/mitchellh/gox \
	github.com/Masterminds/glide \
	github.com/modocache/gover \
	github.com/aktau/github-release && \
	glide install

clean:
	rm -f ./kubesec
	rm -rf ./build

fmt:
	gofmt -l -s -w `find . -type f -name '*.go' -not -path "./vendor/*" -not -path "./.tmp/*"`

test:
	go vet `go list ./... | grep -v /vendor/`
	SRC=`find . -type f -name '*.go' -not -path "./vendor/*" -not -path "./.tmp/*"` && \
		gofmt -l -s $$SRC | read && gofmt -l -s -d $$SRC && exit 1 || true
	go test `go list ./... | grep -v /vendor/`

test-coverage:
	go list ./... | grep -v /vendor/ | xargs -L1 -I{} sh -c 'go test -coverprofile `basename {}`.coverprofile {}' && \
	gover && \
	go tool cover -html=gover.coverprofile -o coverage.html && \
	rm -f *.coverprofile

build:
	go build -ldflags "-X main.version=${VERSION}"

build-release:
	gox -verbose \
	-ldflags "-X main.version=${VERSION}" \
	-osarch="windows/amd64 linux/amd64 darwin/amd64" \
	-output="release/{{.Dir}}-${VERSION}-{{.OS}}-{{.Arch}}" .

publish: clean build-release
	test -n "$(GITHUB_TOKEN)" # $$GITHUB_TOKEN must be set
	github-release release --user shyiko --repo kubesec --tag ${VERSION} \
	--name "${VERSION}" --description "${VERSION}" && \
	github-release upload --user shyiko --repo kubesec --tag ${VERSION} \
	--name "kubesec-${VERSION}-windows-amd64.exe" --file release/kubesec-${VERSION}-windows-amd64.exe; \
	for qualifier in darwin-amd64 linux-amd64 ; do \
		github-release upload --user shyiko --repo kubesec --tag ${VERSION} \
		--name "kubesec-${VERSION}-$$qualifier" --file release/kubesec-${VERSION}-$$qualifier; \
	done

build-docker-image:
	rm -rf /tmp/kubesec-playground && \
	mkdir /tmp/kubesec-playground && \
	docker run --rm -v $$(pwd):/workdir -v /tmp/kubesec-playground:/tmp -w /workdir node:8.2.1 \
		bash -c $$' \
		    npm i gfm-code-blocks mkdirp 1>/dev/null 2>/tmp/npm.log && \
			NODE_PATH=/usr/local/lib/node_modules/ node -e \'require("gfm-code-blocks")(require("fs").readFileSync("README.md", "utf8")).filter(({lang, code}) => lang === "yml" && code.includes("\\n# snippet:")).forEach(({code}) => { const f = code.match("# snippet:(\\\\S+)")[1]; require("mkdirp").sync(`/tmp/README.md/$${require("path").dirname(f)}`); fs.writeFileSync(`/tmp/README.md/$${f}`, code) })\' && \
			chmod -R a+rw /tmp/README.md' && \
	cp kubesec-playground.dockerfile /tmp/kubesec-playground/Dockerfile && \
	bash -c 'cd /tmp/kubesec-playground && docker build -t shyiko/kubesec-playground:0.1.0 .'




